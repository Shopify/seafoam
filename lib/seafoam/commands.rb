require 'json'
require 'set'

module Seafoam
  # Implementations of the command-line commands that you can run in Seafoam.
  class Commands
    def initialize(out)
      @out = out
    end

    # Run the general seafoam command.
    def seafoam(*args)
      first, *args = args

      if first == '--json'
        formatter_module = Seafoam::Formatters::Json
        first, *args = args
      else
        formatter_module = Seafoam::Formatters::Text
      end

      case first
      when nil, 'help', '-h', '--help', '-help'
        raise ArgumentError, "unexpected arguments #{args.join(' ')}" unless args.empty?

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
          info name, formatter_module, *args
        when 'list'
          list name, formatter_module, *args
        when 'search'
          search name, *args
        when 'edges'
          edges name, formatter_module, *args
        when 'props'
          props name, *args
        when 'source'
          source name, formatter_module, *args
        when 'render'
          render name, *args
        when 'debug'
          debug name, *args
        when 'describe'
          describe name, formatter_module, *args
        else
          raise ArgumentError, "unknown command #{command}"
        end
      end
    end

    # Run the bgv2isabelle command.
    def bgv2isabelle(*args)
      case args.first
      when nil, 'help', '-h', '--help', '-help'
        args = args.drop(1)
        raise ArgumentError, "unexpected arguments #{args.join(' ')}" unless args.empty?

        @out.puts 'bgv2isabelle file.bgv...'
        @out.puts '             --help'
        @out.puts '             --version'
      when 'version', '-v', '-version', '--version'
        args = args.drop(1)
        version(*args)
      else
        files = []

        until args.empty?
          arg = args.shift
          if arg.start_with?('-')
            raise ArgumentError, "unknown option #{arg}"
          else
            files.push arg
          end
        end

        writer = IsabelleWriter.new(@out)

        files.each do |file|
          parser = Seafoam::BGV::BGVParser.new(file)
          parser.read_file_header
          parser.skip_document_props

          loop do
            index, = parser.read_graph_preheader
            break unless index

            graph_header = parser.read_graph_header
            name = parser.graph_name(graph_header)
            graph = parser.read_graph

            writer.write index, name, graph
          end
        end
      end
    end

    def bgv2json(*args)
      case args.first
      when nil, 'help', '-h', '--help', '-help'
        args = args.drop(1)
        raise ArgumentError, "unexpected arguments #{args.join(' ')}" unless args.empty?

        @out.puts 'bgv2json file.bgv...'
        @out.puts '         --help'
        @out.puts '         --version'
      when 'version', '-v', '-version', '--version'
        args = args.drop(1)
        version(*args)
      else
        files = []

        until args.empty?
          arg = args.shift
          if arg.start_with?('-')
            raise ArgumentError, "unknown option #{arg}"
          else
            files.push arg
          end
        end

        writer = JSONWriter.new(@out)

        files.each do |file|
          parser = Seafoam::BGV::BGVParser.new(file)
          parser.read_file_header
          parser.skip_document_props

          loop do
            index, = parser.read_graph_preheader
            break unless index

            graph_header = parser.read_graph_header
            name = parser.graph_name(graph_header)
            graph = parser.read_graph

            writer.write name, graph
          end
        end
      end
    end

    private

    # seafoam file.bgv info
    def info(name, formatter_module, *args)
      file, *rest = parse_name(name)
      raise ArgumentError, 'info only works with a file' unless rest == [nil, nil, nil]
      raise ArgumentError, 'info does not take arguments' unless args.empty?

      parser = BGV::BGVParser.new(file)
      major, minor = parser.read_file_header(version_check: false)
      formatter = formatter_module::InfoFormatter.new(major, minor)

      @out.puts formatter.format
    end

    # seafoam file.bgv list
    def list(name, formatter_module, *args)
      file, *rest = parse_name(name)
      raise ArgumentError, 'list only works with a file' unless rest == [nil, nil, nil]
      raise ArgumentError, 'list does not take arguments' unless args.empty?

      parser = BGV::BGVParser.new(file)
      parser.read_file_header
      parser.skip_document_props
      entries = []
      loop do
        index, = parser.read_graph_preheader
        break unless index

        graph_header = parser.read_graph_header
        entries << formatter_module::ListFormatter::Entry.new(file, parser.graph_name(graph_header), index)
        parser.skip_graph
      end

      formatter = formatter_module::ListFormatter.new(entries)
      @out.puts formatter.format
    end

    # seafoam file.bgv:n... search term...
    def search(name, *terms)
      file, graph_index, node_id, = parse_name(name)
      raise ArgumentError, 'search only works with a file or graph' if node_id

      parser = BGV::BGVParser.new(file)
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
      full_text = JSON.generate(JSONWriter.prepare_json(object))
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
    def edges(name, formatter_module, *args)
      file, graph_index, node_id, edge_id = parse_name(name)
      raise ArgumentError, 'edges needs at least a graph' unless graph_index
      raise ArgumentError, 'edges does not take arguments' unless args.empty?

      entry = nil

      with_graph(file, graph_index) do |parser|
        parser.read_graph_header
        graph = parser.read_graph
        if node_id
          Passes.apply graph
          node = graph.nodes[node_id]
          raise ArgumentError, 'node not found' unless node

          if edge_id
            to = graph.nodes[edge_id]
            raise ArgumentError, 'edge node not found' unless to

            edges = node.outputs.select { |edge| edge.to == to }
            raise ArgumentError, 'edge not found' if edges.empty?

            entry = formatter_module::EdgesFormatter::EdgesEntry.new(edges)
          else
            entry = formatter_module::EdgesFormatter::NodeEntry.new(node)
          end
          break
        else
          entry = formatter_module::EdgesFormatter::SummaryEntry.new(graph.nodes.count, graph.edges.count)
        end
      end

      formatter = formatter_module::EdgesFormatter.new(entry)
      @out.puts formatter.format
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
        parser = BGV::BGVParser.new(file)
        parser.read_file_header
        document_props = parser.read_document_props
        pretty_print document_props || {}
      end
    end

    # seafoam file.bgv:n:n source
    def source(name, formatter_module, *args)
      file, graph_index, node_id, edge_id = parse_name(name)
      raise ArgumentError, 'source needs a node' unless node_id
      raise ArgumentError, 'source only works with a node' if edge_id
      raise ArgumentError, 'source does not take arguments' unless args.empty?

      with_graph(file, graph_index) do |parser|
        parser.read_graph_header
        graph = parser.read_graph
        node = graph.nodes[node_id]
        raise ArgumentError, 'node not found' unless node

        formatter = formatter_module::SourceFormatter.new(node.props['nodeSourcePosition'])
        @out.puts formatter.format
      end
    end

    # seafoam file.bgv:n describe
    def describe(name, formatter_module, *args)
      file, graph_index, *rest = parse_name(name)

      if graph_index.nil? || !rest.all?(&:nil?)
        raise ArgumentError, 'describe only works with a graph'
      end
      raise ArgumentError, 'describe does not take arguments' unless args.empty?

      parser = BGV::BGVParser.new(file)
      parser.read_file_header
      parser.skip_document_props

      loop do
        index, = parser.read_graph_preheader
        break unless index

        parser.skip_graph_header

        if index != graph_index
          parser.skip_graph
          next
        end

        graph = parser.read_graph
        description = Seafoam::Graal::GraphDescription.new

        graph.nodes.each_value do |node|
          node_class = node.node_class

          simple_node_class = node_class[/([^.]+)$/, 1]
          description.node_counts[simple_node_class] += 1

          case node_class
          when 'org.graalvm.compiler.nodes.IfNode'
            description.branches = true
          when 'org.graalvm.compiler.nodes.LoopBeginNode'
            description.loops = true
          when 'org.graalvm.compiler.nodes.InvokeNode', 'org.graalvm.compiler.nodes.InvokeWithExceptionNode'
            description.calls = true
          end
        end

        description.deopts = graph.nodes[0].outputs.map(&:to)
                                  .all? { |t| t.node_class == 'org.graalvm.compiler.nodes.DeoptimizeNode' }

        formatter = formatter_module::DescribeFormatter.new(graph, description)
        @out.puts formatter.format

        break
      end
    end

    # seafoam file.bgv:n render options...
    def render(name, *args)
      file, graph_index, *rest = parse_name(name)
      raise ArgumentError, 'render needs at least a graph' unless graph_index
      raise ArgumentError, 'render only works with a graph' unless rest == [nil, nil]

      pass_options = {
        simplify_truffle_args: true,
        hide_frame_state: true,
        hide_pi: true,
        hide_begin_end: true,
        hide_floating: false,
        reduce_edges: true
      }
      spotlight_nodes = nil
      args = args.dup
      out_file = nil
      explicit_out_file = false
      draw_blocks = false
      until args.empty?
        arg = args.shift
        case arg
        when '--out'
          out_file = args.shift
          explicit_out_file = true
          raise ArgumentError, 'no file for --out' unless out_file

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
          when '.mmd'
            out_format = :mmd
          when '.md'
            out_format = :md
          else
            raise ArgumentError, "unknown render format #{out_ext}"
          end
        when '--md'
          out_file = @out
          out_format = :md
          explicit_out_file = true
        when '--spotlight'
          spotlight_arg = args.shift
          raise ArgumentError, 'no list for --spotlight' unless spotlight_arg

          spotlight_nodes = spotlight_arg.split(',').map { |n| Integer(n) }
        when '--full-truffle-args'
          pass_options[:simplify_truffle_args] = false
        when '--show-frame-state'
          pass_options[:hide_frame_state] = false
        when '--show-pi'
          pass_options[:hide_pi] = false
        when '--show-begin-end'
          pass_options[:hide_begin_end] = false
        when '--hide-floating'
          pass_options[:hide_floating] = true
        when '--no-reduce-edges'
          pass_options[:reduce_edges] = false
        when '--draw-blocks'
          draw_blocks = true
        when '--option'
          key = args.shift
          raise ArgumentError, 'no key for --option' unless key

          value = args.shift
          raise ArgumentError, "no value for --option #{key}" unless out_file

          value = { 'true' => true, 'false' => 'false' }.fetch(key, value)
          pass_options[key.to_sym] = value
        else
          raise ArgumentError, "unexpected option #{arg}"
        end
      end
      out_file ||= 'graph.pdf'
      out_format ||= :pdf
      with_graph(file, graph_index) do |parser|
        parser.skip_graph_header
        graph = parser.read_graph
        Passes.apply graph, pass_options
        if spotlight_nodes
          spotlight = Spotlight.new(graph)
          spotlight_nodes.each do |node_id|
            node = graph.nodes[node_id]
            raise ArgumentError, 'node not found' unless node

            spotlight.light node
          end
          spotlight.shade
        end
        case out_format
        when :dot, :mmd, :md
          action = lambda do |stream|
            case out_format
            when :dot
              writer = GraphvizWriter.new(stream)
              writer.write_graph graph, false, draw_blocks
            when :mmd
              writer = MermaidWriter.new(stream)
              writer.write_graph graph
            when :md
              writer = MarkdownWriter.new(stream)
              writer.write_graph graph
            else
              raise
            end
          end
          if out_file.is_a?(String)
            File.open(out_file, 'w') do |stream|
              action.call stream
            end
          else
            action.call out_file
          end
        else
          begin
            IO.popen(['dot', "-T#{out_format}", '-o', out_file], 'w') do |stream|
              writer = GraphvizWriter.new(stream)
              hidpi = out_format == :png
              writer.write_graph graph, hidpi, draw_blocks
            end
          rescue Errno::ENOENT
            raise 'Could not run Graphviz - is it installed?'
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
    class BGVDebugParser < BGV::BGVParser
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
      parser = BGV::BGVParser.new(file)
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
    def help(*_args)
      @out.puts 'seafoam file.bgv info'
      @out.puts '        file.bgv list'
      @out.puts '        file.bgv[:graph][:node[-edge]] search term...'
      @out.puts '        file.bgv[:graph][:node[-edge]] edges'
      @out.puts '        file.bgv[:graph][:node[-edge]] props'
      @out.puts '        file.bgv:graph:node source'
      @out.puts '        file.bgv:graph describe'
      @out.puts '        file.bgv:graph render'
      @out.puts '              --spotlight n,n,n...'
      @out.puts '              --out graph.pdf'
      @out.puts '                    graph.svg'
      @out.puts '                    graph.png'
      @out.puts '                    graph.dot (Graphviz)'
      @out.puts '                    graph.mmd (Mermaid)'
      @out.puts '                    graph.md (Markdown)'
      @out.puts '               --full-truffle-args'
      @out.puts '               --show-frame-state'
      @out.puts '               --show-pi'
      @out.puts '               --show-begin-end'
      @out.puts '               --hide-floating'
      @out.puts '               --no-reduce-edges'
      @out.puts '               --draw-blocks'
      @out.puts '               --option key value'
      @out.puts '        --help'
      @out.puts '        --version'
    end

    # Prints the version.
    def version(*args)
      raise ArgumentError, "unexpected arguments #{args.join(' ')}" unless args.empty?

      @out.puts "seafoam #{VERSION}"
    end

    # Parse a name like file.bgv:g:n-e to [file.bgv, g, n, e].
    def parse_name(name)
      *pre, post = name.split('.')

      file_ext, graph, node, *rest = post.split(':')
      raise ArgumentError, "too many parts to .ext:g:n-e in #{name}" unless rest.empty?

      file = [*pre, file_ext].join('.')

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
      return unless @out.tty?

      case RUBY_PLATFORM
      when /darwin/
        system 'open', file
      when /linux/
        system 'xdg-open', file
      end
      # Don't worry if it fails.
    end
  end
end
