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
      command, *args = args
      case command
      when 'info'
        info(*args)
      when 'list'
        list(*args)
      when 'search'
        search(*args)
      when 'edges'
        edges(*args)
      when 'props'
        props(*args)
      when 'render'
        render(*args)
      when 'decompile'
        decompile(*args)
      when 'debug'
        debug(*args)
      when nil, 'help', '-h', '--help', '-help'
        help(*args)
      when 'version', '-v', '-version', '--version'
        version(*args)
      else
        raise ArgumentError, "unknown command #{command}"
      end
    end

    private

    # seafoam info file.bgv
    def info(*args)
      files = []
      args.each do |arg|
        if arg.start_with?('-')
          raise ArgumentError, "unexpected option #{arg}"
        else
          files.push arg
        end
      end
      files.each do |file|
        file, *rest = parse_name(file)
        raise ArgumentError, 'info only works with a file' unless rest == [nil, nil, nil]

        File.open(file) do |stream|
          parser = BGVParser.new(stream)
          major, minor = parser.read_file_header(version_check: false)
          @out.puts "BGV #{major}.#{minor}"
        end
      end
    end

    # seafoam list file.bgv
    def list(*args)
      files = []
      args.each do |arg|
        if arg.start_with?('-')
          raise ArgumentError, "unexpected option #{arg}"
        else
          files.push arg
        end
      end
      files.each do |file|
        file, *rest = parse_name(file)
        raise ArgumentError, 'list only works with a file' unless rest == [nil, nil, nil]

        File.open(file) do |stream|
          parser = BGVParser.new(stream)
          parser.read_file_header
          loop do
            index, = parser.read_graph_preheader
            break unless index

            graph_header = parser.read_graph_header
            @out.puts "#{file}:#{index}  #{parser.graph_name(graph_header)}"
            parser.skip_graph
          end
        end
      end
    end

    # seafoam search file.bgv:n... term...
    def search(*args)
      files = []
      terms = []
      until args.empty?
        arg = args.shift
        if arg.start_with?('-')
          case arg
          when '--'
            terms.push args.shift until args.empty?
          else
            raise ArgumentError, "unexpected option #{arg}"
          end
        else
          files.push arg
        end
      end
      files.each do |file|
        file, graph_index, node_id, = parse_name(file)
        raise ArgumentError, 'search only works with a file or graph' if node_id

        File.open(file) do |stream|
          parser = BGVParser.new(stream)
          parser.read_file_header
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

    # seafoam edges file.bgv:n...
    def edges(*args)
      files = []
      args.each do |arg|
        if arg.start_with?('-')
          raise ArgumentError, "unexpected option #{arg}"
        else
          files.push arg
        end
      end
      files.each do |file|
        file, graph_index, node_id, edge_id = parse_name(file)
        raise ArgumentError, 'edges needs at least a graph' unless graph_index

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

              edges = node.outputs.filter { |edge| edge.to == to }
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
    end

    # seafoam props file.bgv:n
    def props(*args)
      files = []
      args.each do |arg|
        if arg.start_with?('-')
          raise ArgumentError, "unexpected option #{arg}"
        else
          files.push arg
        end
      end
      files.each do |file|
        file, graph_index, node_id, edge_id = parse_name(file)
        raise ArgumentError, 'props needs at least a graph' unless graph_index

        with_graph(file, graph_index) do |parser|
          graph_header = parser.read_graph_header
          if node_id
            graph = parser.read_graph
            node = graph.nodes[node_id]
            raise ArgumentError, 'node not found' unless node

            if edge_id
              to = graph.nodes[edge_id]
              raise ArgumentError, 'edge node not found' unless to

              edges = node.outputs.filter { |edge| edge.to == to }
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
      end
    end

    # seafoam render file.bgv:0
    def render(*args)
      files = []
      annotator_options = {
        hide_frame_state: true,
        hide_floating: false,
        reduce_edges: true
      }
      spotlight_nodes = nil
      args = args.dup
      out_file = nil
      until args.empty?
        arg = args.shift
        if arg.start_with?('-')
          case arg
          when '-o'
            out_file = args.shift
            raise ArgumentError, 'no file for -o' unless out_file
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
        else
          files.push arg
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
      files.each do |file|
        file, graph_index, *rest = parse_name(file)
        raise ArgumentError, 'render needs at least a graph' unless graph_index
        raise ArgumentError, 'render only works with a graph' unless rest == [nil, nil]

        with_graph(file, graph_index) do |parser|
          parser.skip_graph_header
          graph = parser.read_graph
          Annotators.apply graph, annotator_options

          decompiler = Decompiler.new(graph)
          graph.nodes.values.each do |node|
            decompiler.decompile(node)
          end
          graph.nodes.each_value do |node|
            node.props[:label] = "#{node.props[:label]} | #{node.props[Decompiler::DECOMPILED_PROP]}"
          end
          # puts decompiler.collect

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
              writer.write_graph graph
            end
            autoopen out_file
          end
        end
      end
    end

    # seafoam debug file.bgv
    def debug(*args)
      files = []
      skip = false
      args.each do |arg|
        if arg.start_with?('-')
          case arg
          when '--skip'
            skip = true
          else
            raise ArgumentError, "unexpected option #{arg}"
          end
        else
          files.push arg
        end
      end
      files.each do |file|
        file, *rest = parse_name(file)
        raise ArgumentError, 'debug only works with a file' unless rest == [nil, nil, nil]

        @out.puts file
        File.open(file) do |stream|
          parser = BGVDebugParser.new(@out, stream)
          pretty_print parser.read_file_header
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

    def decompile(*args)
      files = []
      args.each do |arg|
        files << arg unless arg.start_with?('-')
      end
      annotator_options = {
        hide_frame_state: true,
        hide_floating: false,
        reduce_edges: false
      }
      files.each do |file|
        file, graph_index, *rest = parse_name(file)
        raise ArgumentError, 'decompile needs at least a graph' unless graph_index
        raise ArgumentError, 'decompile only works with a single graph' unless rest == [nil, nil]

        with_graph(file, graph_index) do |parser|
          parser.skip_graph_header
          graph = parser.read_graph
          Annotators.apply graph, annotator_options

          # graph.nodes.each_pair do |index, node|
          #   p [index, node]
          # end

          decompiler = Decompiler.new(graph)
          graph.nodes.values.each do |node|
            decompiler.decompile(node)
          end
          require 'pry'; binding.pry
          p graph.nodes[11].props[:decompiled]
          p graph.nodes[8].props[:decompiled]
          p graph.nodes[5].props[:decompiled]
          p graph.nodes[6].props[:decompiled]

          # node.edges.each do |edge|
          #   if edge.to == node
          #     p edge
          #   end
          # end
          # require 'pry'
          # binding.pry
        end
      end
    end


    class Decompiler
      DECOMPILED_PROP = :decop_decompiled
      MAX_VARIABLE_PROP = :decomp_max_variable
      def initialize(graph)
        @graph = graph
        @max_var_id = 0
      end

      def decompile(node)
        return if node.props[DECOMPILED_PROP]
        # detect binary operands
        node_class = node.props.dig(:node_class, :node_class)
        # require 'pry'
        # binding.pry
        if node_class.is_a?(String)
          last_part = node_class.split('.').last
          case last_part
          when "ConstantNode"
            node.props[DECOMPILED_PROP] = node.props["rawvalue"]
          when "ParameterNode"
            node.props[DECOMPILED_PROP] = "arg#{node.props["index"]}"
          when "IfNode"
            condition_edge = node.edges.find do |edge|
              edge.props[:type] == "Condition"
            end
            raise "condition input not found for if node" unless condition_edge
            decompile(condition_edge.from)

            node.props[DECOMPILED_PROP] = "if #{condition_edge.from.props[DECOMPILED_PROP]}"
          when "MethodCallTargetNode"
            target_name = node.props.dig("targetMethod", :method_name)
            raise "can't find target name" unless target_name
            decompiled_arguments = node.inputs.map do |edge|
              next nil unless edge.props[:name] == "arguments"
              decompile(edge.from)
              edge.from.props[DECOMPILED_PROP]
              # TODO: we are assuming that the arguments show up in the order they are listed in Node#inputs.
              # not sure if this is an okay assumption
            end.compact

            node.props[DECOMPILED_PROP] = "#{target_name}(#{decompiled_arguments.join(', ')})"
          when "InvokeNode"
            call_target_edge = node.inputs.find do |edge|
              edge.props[:name] == "callTarget"
            end
            raise "can't find call target from InvokeNode" unless call_target_edge
            decompile(call_target_edge.from)

            node.props[DECOMPILED_PROP] = call_target_edge.from.props[DECOMPILED_PROP]

            has_data_output = node.outputs.find { |e| e.props[:kind] == 'data' }
            if has_data_output
              # make a temporary varaible for the return value this call node
              var_name = "ret#{new_var_id}"
              control_input = node.inputs.find { |e| e.props[:kind] == 'control' }
              assignment = @graph.create_node(@graph.nodes.keys.max + 1, DECOMPILED_PROP => "#{var_name} = #{node.props[DECOMPILED_PROP]}")
              @graph.replace_edge_destination(control_input, assignment)
              @graph.create_edge(assignment, node, kind: 'control')

              node.props[DECOMPILED_PROP] = "#{var_name}"
            end
          when "ValuePhiNode"
            phi = node
            merge = phi.inputs.find { |e| e.from.props.dig(:node_class,:node_class).end_with?("MergeNode") }
            unless merge
              $stderr.puts "seafoam: warning: skipping phi node that doen't succeed a merge node" if $DEBUG
              return
            end
            merge = merge.from

            phi_inputs = phi.inputs.select { |edge| edge.props[:name] == 'values' }.map!(&:from)
            phi_inputs.each do |input_node|
              decompile(input_node)
            end

            phi_varaible_name = "temp#{new_var_id}"

            ends = merge.inputs.select { |e| e.props[:name] == 'ends' }.map(&:from)
            raise "number of ends don't match number of phi inputs" unless ends.size == phi_inputs.size
            phi_inputs.zip(ends) do |rhs_assignment, end_node|
              end_node.props[DECOMPILED_PROP] ||= ''
              prefix = if end_node.props[DECOMPILED_PROP].empty?
                ''
              else
                "\n"
              end

              end_node.props[DECOMPILED_PROP] += "#{prefix}#{phi_varaible_name} = #{rhs_assignment.props[DECOMPILED_PROP]}"
            end
            phi.props[DECOMPILED_PROP] = phi_varaible_name
          when "FixedGuardNode"
            condition = node.inputs.find { |edge| edge.props[:name] == 'condition' }
            raise "no condition edge" unless condition
            condition = condition.from

            decompile(condition)
            node.props[DECOMPILED_PROP] = "raise unless #{condition.props[DECOMPILED_PROP]}"
          end

          return if node.props[DECOMPILED_PROP]
        end

        data_input_edges = node.inputs.select { |edge| edge.props[:kind] == "data" }
        if node.props[:kind] == "op" && data_input_edges.size == 2
          # TODO: ordering. are we sure that x is always the first edge?
          x, y = data_input_edges
          decompile(x.from)
          decompile(y.from)
          node.props[DECOMPILED_PROP] = "#{x.from.props[DECOMPILED_PROP]} #{node.props.dig(:node_class, :name_template)} #{y.from.props[DECOMPILED_PROP]}"
        end
      end

      def new_var_id
        id = @max_var_id
        @max_var_id += 1
        id
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
      File.open(file) do |stream|
        parser = BGVParser.new(stream)
        parser.read_file_header
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
    end

    # Prints help.
    def help(*args)
      raise ArgumentError, "unexpected arguments #{args.join(' ')}" unless args.empty?

      @out.puts 'seafoam info file.bgv'
      @out.puts '        list file.bgv'
      @out.puts '        search file.bgv[:graph][:node[-edge]] -- term...'
      @out.puts '        edges file.bgv[:graph][:node[-edge]]'
      @out.puts '        props file.bgv[:graph][:node[-edge]]'
      @out.puts '        render file.bgv:graph'
      @out.puts '              --spotlight n,n,n...'
      @out.puts '               -o graph.pdf'
      @out.puts '                  graph.svg'
      @out.puts '                  graph.png'
      @out.puts '                  graph.dot'
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
      file, graph, node, *rest = name.split(':')
      raise ArgumentError, "too many parts to name #{name}" unless rest.empty?

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
