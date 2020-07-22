require 'json'

module Seafoam
  # Implementations of the command-line commands that you can run in Seafoam.
  class Commands
    def initialize(out, config)
      @out = out
      @config = config
    end

    # Run any command.
    def run(*args)
      first, *args = args
      case first
      when nil, 'help', '-h', '--help', '-help'
        help(*args)
      when 'version', '-v', '-version', '--version'
        version(*args)
      else
        name = first
        command, *args = args
        case command
        when nil
          help(*args)
        when 'info'
          info name, *args
        when 'list'
          list name, *args
        when 'search'
          search name, *args
        when 'edges'
          edges name, *args
        when 'props'
          props name, *args
        when 'render'
          render name, *args
        when 'debug'
          debug name, *args
        else
          raise ArgumentError, "unknown command #{command}"
        end
      end
    end

    private

    # seafoam file.bgv info
    def info(name, *args)
      file, *rest = parse_name(name)
      raise ArgumentError, 'info only works with a file' unless rest == [nil, nil, nil]

      raise ArgumentError, 'info does not take arguments' unless args.empty?

      parser = BGVParser.new(File.new(file))
      major, minor = parser.read_file_header(version_check: false)
      @out.puts "BGV #{major}.#{minor}"
    end

    # seafoam file.bgv list
    def list(name, *args)
      file, *rest = parse_name(name)
      raise ArgumentError, 'list only works with a file' unless rest == [nil, nil, nil]

      raise ArgumentError, 'list does not take arguments' unless args.empty?

      parser = BGVParser.new(File.new(file))
      parser.read_file_header
      parser.skip_document_props
      loop do
        index, = parser.read_graph_preheader
        break unless index

        graph_header = parser.read_graph_header
        @out.puts "#{file}:#{index}  #{parser.graph_name(graph_header)}"
        parser.skip_graph
      end
    end

    # seafoam file.bgv:n... search term...
    def search(name, *terms)
      file, graph_index, node_id, = parse_name(name)
      raise ArgumentError, 'search only works with a file or graph' if node_id

      parser = BGVParser.new(File.new(file))
      parser.read_file_header
      parser.skip_document_props
      loop do
        index, = parser.read_graph_preheader
        break unless index

        if !graph_index || index == graph_index
          header = parser.read_graph_header
          search_object "#{file}:#{index}", header, terms
          graph = parser.read_graph
          graph.nodes.each_value do |node|
            search_object "#{file}:#{index}:#{node.id}", node.props, terms
          end
          graph.edges.each do |edge|
            search_object "#{file}:#{index}:#{edge.from.id}-#{edge.to.id}", edge.props, terms
          end
        else
          parser.skip_graph_header
          parser.skip_graph
        end
      end
    end

    def search_object(tag, object, terms)
      full_text = JSON.generate(object)
      full_text_down = full_text.downcase
      start = 0
      terms.each do |t|
        loop do
          index = full_text_down.index(t.downcase, start)
          break unless index

          context = 40
          before = full_text[index - context, context]
          match = full_text[index, t.size]
          after = full_text[index + t.size, context]
          if @out.tty?
            highlight_on = "\033[1m"
            highlight_off = "\033[0m"
          else
            highlight_on = ''
            highlight_off = ''
          end
          @out.puts "#{tag}  ...#{before}#{highlight_on}#{match}#{highlight_off}#{after}..."
          start = index + t.size
        end
      end
    end

    # seafoam file.bgv:n... edges
    def edges(name, *args)
      file, graph_index, node_id, edge_id = parse_name(name)
      raise ArgumentError, 'edges needs at least a graph' unless graph_index

      raise ArgumentError, 'edges does not take arguments' unless args.empty?

      with_graph(file, graph_index) do |parser|
        parser.read_graph_header
        graph = parser.read_graph
        if node_id
          Annotators.apply graph
          node = graph.nodes[node_id]
          raise ArgumentError, 'node not found' unless node

          if edge_id
            to = graph.nodes[edge_id]
            raise ArgumentError, 'edge node not found' unless to

            edges = node.outputs.select { |edge| edge.to == to }
            raise ArgumentError, 'edge not found' if edges.empty?

            edges.each do |edge|
              @out.puts "#{edge.from.id_and_label} ->(#{edge.props[:label]}) #{edge.to.id_and_label}"
            end
          else
            @out.puts 'Input:'
            node.inputs.each do |input|
              @out.puts "  #{node.id_and_label} <-(#{input.props[:label]}) #{input.from.id_and_label}"
            end
            @out.puts 'Output:'
            node.outputs.each do |output|
              @out.puts "  #{node.id_and_label} ->(#{output.props[:label]}) #{output.to.id_and_label}"
            end
          end
          break
        else
          @out.puts "#{graph.nodes.count} nodes, #{graph.edges.count} edges"
        end
      end
    end

    # seafoam file.bgv... props
    def props(name, *args)
      file, graph_index, node_id, edge_id = parse_name(name)
      raise ArgumentError, 'props does not take arguments' unless args.empty?

      if graph_index
        with_graph(file, graph_index) do |parser|
          graph_header = parser.read_graph_header
          if node_id
            graph = parser.read_graph
            node = graph.nodes[node_id]
            raise ArgumentError, 'node not found' unless node

            if edge_id
              to = graph.nodes[edge_id]
              raise ArgumentError, 'edge node not found' unless to

              edges = node.outputs.select { |edge| edge.to == to }
              raise ArgumentError, 'edge not found' if edges.empty?

              if edges.size > 1
                edges.each do |edge|
                  pretty_print edge.props
                  @out.puts
                end
              else
                pretty_print edges.first.props
              end
            else
              pretty_print node.props
            end
            break
          else
            pretty_print graph_header
            parser.skip_graph
          end
        end
      else
        parser = BGVParser.new(File.new(file))
        parser.read_file_header
        document_props = parser.read_document_props
        pretty_print document_props || {}
      end
    end

    # seafoam file.bgv:0 render options...
    def render(name, *args)
      file, graph_index, *rest = parse_name(name)
      raise ArgumentError, 'render needs at least a graph' unless graph_index
      raise ArgumentError, 'render only works with a graph' unless rest == [nil, nil]

      annotator_options = {
        hide_frame_state: true,
        hide_floating: false,
        reduce_edges: true
      }
      spotlight_nodes = nil
      args = args.dup
      out_file = nil
      explicit_out_file = false
      until args.empty?
        arg = args.shift
        case arg
        when '--out'
          out_file = args.shift
          explicit_out_file = true
          raise ArgumentError, 'no file for --out' unless out_file
        when '--spotlight'
          spotlight_arg = args.shift
          raise ArgumentError, 'no list for --spotlight' unless spotlight_arg

          spotlight_nodes = spotlight_arg.split(',').map { |n| Integer(n) }
        when '--show-frame-state'
          annotator_options[:hide_frame_state] = false
        when '--hide-floating'
          annotator_options[:hide_floating] = true
        when '--no-reduce-edges'
          annotator_options[:reduce_edges] = false
        when '--option'
          key = args.shift
          raise ArgumentError, 'no key for --option' unless key

          value = args.shift
          raise ArgumentError, "no value for --option #{key}" unless out_file

          value = { 'true' => true, 'false' => 'false' }.fetch(key, value)
          annotator_options[key.to_sym] = value
        else
          raise ArgumentError, "unexpected option #{arg}"
        end
      end
      out_file ||= 'graph.pdf'
      out_ext = File.extname(out_file).downcase
      case out_ext
      when '.pdf'
        out_format = :pdf
      when '.svg'
        out_format = :svg
      when '.png'
        out_format = :png
      when '.dot'
        out_format = :dot
      else
        raise ArgumentError, "unknown render format #{out_ext}"
      end

      with_graph(file, graph_index) do |parser|
        parser.skip_graph_header
        graph = parser.read_graph
        Annotators.apply graph, annotator_options
        if spotlight_nodes
          spotlight = Spotlight.new(graph)
          spotlight_nodes.each do |node_id|
            node = graph.nodes[node_id]
            raise ArgumentError, 'node not found' unless node

            spotlight.light node
          end
          spotlight.shade
        end
        if out_format == :dot
          File.open(out_file, 'w') do |stream|
            writer = GraphvizWriter.new(stream)
            writer.write_graph graph
          end
        else
          IO.popen(['dot', "-T#{out_format}", '-o', out_file], 'w') do |stream|
            writer = GraphvizWriter.new(stream)
            hidpi = out_format == :png
            writer.write_graph graph, hidpi
          end
          autoopen out_file unless explicit_out_file
        end
      end
    end

    # seafoam file.bgv debug options...
    def debug(name, *args)
      file, *rest = parse_name(name)
      raise ArgumentError, 'debug only works with a file' unless rest == [nil, nil, nil]

      skip = false
      args.each do |arg|
        case arg
        when '--skip'
          skip = true
        else
          raise ArgumentError, "unexpected option #{arg}"
        end
      end

      File.open(file) do |stream|
        parser = BGVDebugParser.new(@out, stream)
        begin
          pretty_print parser.read_file_header
          document_props = parser.read_document_props
          if document_props
            pretty_print document_props
          end
          loop do
            index, id = parser.read_graph_preheader
            break unless index

            @out.puts "graph #{index}, id=#{id}"
            if skip
              parser.skip_graph_header
              parser.skip_graph
            else
              pretty_print parser.read_graph_header
              pretty_print parser.read_graph
            end
          end
        rescue StandardError => e
          @out.puts "#{e} before byte #{stream.tell}"
          @out.puts e.backtrace
        end
      end
    end

    # A subclass of BGVParser which prints when pool entries are added.
    class BGVDebugParser < BGVParser
      def initialize(out, *args)
        super(*args)
        @out = out
      end

      def set_pool_entry(id, object)
        @out.puts "pool #{id} = #{object}"
        super
      end
    end

    # Reads a file and yields just the graph requested by the index - skipping
    # the rest of the file as best as possible.
    def with_graph(file, graph_index)
      parser = BGVParser.new(File.new(file))
      parser.read_file_header
      parser.skip_document_props
      graph_found = false
      loop do
        index, = parser.read_graph_preheader
        break unless index

        if index == graph_index
          graph_found = true
          yield parser
          break
        else
          parser.skip_graph_header
          parser.skip_graph
        end
      end
      raise ArgumentError, 'graph not found' unless graph_found
    end

    # Prints help.
    def help(*args)
      raise ArgumentError, "unexpected arguments #{args.join(' ')}" unless args.empty?

      @out.puts 'seafoam file.bgv info'
      @out.puts '        file.bgv list'
      @out.puts '        file.bgv[:graph][:node[-edge]] search term...'
      @out.puts '        file.bgv[:graph][:node[-edge]] edges'
      @out.puts '        file.bgv[:graph][:node[-edge]] props'
      @out.puts '        file.bgv:graph render'
      @out.puts '              --spotlight n,n,n...'
      @out.puts '              --out graph.pdf'
      @out.puts '                    graph.svg'
      @out.puts '                    graph.png'
      @out.puts '                    graph.dot'
      @out.puts '               --show-frame-state'
      @out.puts '               --hide-floating'
      @out.puts '               --no-reduce-edges'
      @out.puts '               --option key value'
    end

    # Prints the version.
    def version(*args)
      raise ArgumentError, "unexpected arguments #{args.join(' ')}" unless args.empty?

      @out.puts "seafoam #{VERSION}"
    end

    # Parse a name like file.bgv:g:n-e to [file.bgv, g, n, e].
    def parse_name(name)
      *pre, file, graph, node = name.split(':')
      file = [*pre, file].join(':')

      if node
        node, edge, *rest = node.split('-')
        raise ArgumentError, "too many parts to edge name in #{name}" unless rest.empty?
      else
        node = nil
        edge = nil
      end
      [file] + [graph, node, edge].map { |i| i.nil? ? nil : Integer(i) }
    end

    # Pretty-print a JSON-style object.
    def pretty_print(props)
      @out.puts JSON.pretty_generate(props)
    end

    # Open a file for the user if possible.
    def autoopen(file)
      if RUBY_PLATFORM.include?('darwin') && @out.tty?
        system 'open', file
        # Don't worry if it fails.
      end
    end
  end
end
