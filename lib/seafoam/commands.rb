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
          puts decompiler.collect

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
      DECOMPILED_PROP = :decomp_decompiled
      FAILURE_REASON_PROP = :decomp_failure_reason
      MAX_VARIABLE_PROP = :decomp_max_variable
      SKIP_DURING_COLLECTION_PROP = :decomp_skip_during_collection

      def initialize(graph)
        @graph = graph
        @max_var_id = 0
      end

      # a final pass to assemble the final output
      def collect
        node = @graph.nodes[0]
        raise "expected node[0] to be a start node" unless node.props.dig(:node_class, :node_class)&.end_with?("StartNode")
        Collector.new.collect(node)
      end

      def decompile(node)
        decompile_body(node, unwind_on_failure: false)
      end

      private

      module DecompilerRefinements
        # for notational convinience: node.whatever instead of whatever(node)
        refine Node do
          def to_s
            klass = node_class
            node_class_str = if klass
              klass.split('.').last
            end
            "<#{node_class_str}##{self.id}>"
          end

          def decompiled
            props[DECOMPILED_PROP]
          end

          def decompiled=(value)
            props[DECOMPILED_PROP] = value
          end

          def failure_reason
            props[FAILURE_REASON_PROP]
          end

          def failure_reason=(value)
            props[FAILURE_REASON_PROP] = value
          end

          def node_class
            props.dig(:node_class, :node_class)
          end
        end
      end
      using DecompilerRefinements

      def decompile_body(node, unwind_on_failure: true)

        decompiled_source = node.decompiled
        return decompiled_source if decompiled_source

        begin
          decompile_one(node, unwind_on_failure: unwind_on_failure)
          if unwind_on_failure
            success = !!node.decompiled
          end
        rescue Unwind => unwind
          if unwind_on_failure
            unwind.could_not_satisfy_dependency(node)
            raise
          else
            first_failure = unwind.unsatisfied_dependency.first

            node.failure_reason = "#{node} depends on unhandleable #{first_failure}: #{first_failure.props[FAILURE_REASON_PROP]}"
          end
        end

        if unwind_on_failure
          raise Unwind.new(node) unless success
        end
      end

      # this one could raise
      def decompile_one(node, unwind_on_failure:)
        node_class = node.props.dig(:node_class, :node_class)
        if node_class.is_a?(String)
          last_part = node_class.split('.').last
          case last_part
          when "ConstantNode"
            node.decompiled = node.props["rawvalue"]
          when "ParameterNode"
            node.decompiled = "arg#{node.props["index"]}"
          when "IfNode"
            condition_edge = node.edges.find do |edge|
              edge.props[:type] == "Condition"
            end
            raise "condition input not found for if node" unless condition_edge
            decompile_body(condition_edge.from)

            node.decompiled = "if #{condition_edge.from.props[DECOMPILED_PROP]}"
          when "MethodCallTargetNode"
            target_name = node.props.dig("targetMethod", :method_name)
            raise "can't find target name" unless target_name
            decompiled_arguments = node.inputs.map do |edge|
              next nil unless edge.props[:name] == "arguments"
              decompile_body(edge.from)
              edge.from.props[DECOMPILED_PROP]
              # TODO: we are assuming that the arguments show up in the order they are listed in Node#inputs.
              # not sure if this is an okay assumption
            end.compact

            node.decompiled = "#{target_name}(#{decompiled_arguments.join(', ')})"
          when "InvokeNode"
            call_target_edge = node.inputs.find do |edge|
              edge.props[:name] == "callTarget"
            end
            raise "can't find call target from InvokeNode" unless call_target_edge
            decompile_body(call_target_edge.from)

            node.decompiled = call_target_edge.from.props[DECOMPILED_PROP]

            has_data_output = node.outputs.find { |e| e.props[:kind] == 'data' }
            if has_data_output
              # make a temporary varaible for the return value of this call node
              var_name = "ret#{new_var_id}"
              control_input = node.inputs.find { |e| e.props[:kind] == 'control' }
              assignment = @graph.create_node(@graph.nodes.keys.max + 1, DECOMPILED_PROP => "#{var_name} = #{node.decompiled}")
              @graph.replace_edge_destination(control_input, assignment)
              @graph.create_edge(assignment, node, kind: 'control')

              node.decompiled = "#{var_name}"
              node.props[SKIP_DURING_COLLECTION_PROP] = true
            end
          when "ValuePhiNode"
            # I'm very unsure about whether this node is implemented correctly. Through a some quick search, I couldn't find
            # explicit documentation on the the correct way to use other nodes to reconstruct the full picture. This code was
            # written by writing different programs and observing the output graph.
            phi = node
            case
            when (merge = phi.inputs.find { |e| e.from.node_class.end_with?("MergeNode") })
              merge = merge.from

              phi_inputs = phi.inputs.select { |edge| edge.props[:name] == 'values' }.map!(&:from)
              phi_inputs.each do |input_node|
                decompile_body(input_node)
              end

              phi_varaible_name = "temp#{new_var_id}"

              ends = merge.inputs.select { |e| e.props[:name] == 'ends' }.map(&:from)
              raise "number of ends don't match number of phi inputs" unless ends.size == phi_inputs.size
              phi_inputs.zip(ends) do |rhs_assignment, end_node|
                end_node.decompiled ||= []
                if end_node.decompiled.is_a?(String)
                  end_node.decompiled = [end_node.decompiled]
                end

                end_node.decompiled << "#{phi_varaible_name} = #{rhs_assignment.props[DECOMPILED_PROP]}"
              end
              phi.decompiled = phi_varaible_name
            when (loop_begin = phi.inputs.find { |edge| edge.from.node_class.end_with?("LoopBeginNode") })
              # basically sink the assignment to the loop variable as low as possible inside the loop
              p 'hu heu huehe uehue he ueh u'
            else
              node.failure_reason = "could not find known input edge type for phi"
            end
          when "FixedGuardNode"
            condition = input_edge_or_unwind(node, :name, 'condition')
            decompile_body(condition.from)
            node.decompiled = "raise #{node.props["reason"]} unless #{condition.from.decompiled}"
          when "ReturnNode"
            data_input = node.inputs.find { |edge| edge.props[:kind] == "data" }
            if data_input
              decompile_body(data_input.from)
              node.decompiled = "return #{data_input.from.props[DECOMPILED_PROP]}"
            else
              node.decompiled = "return"
            end
          when "PiArrayNode"
            # it looks like this node is for storing the length of an input array?
            array_input = input_edge_or_unwind(node, :name, "object")
            decompile_body(array_input.from)
            node.decompiled = array_input.from.props[DECOMPILED_PROP]
          when "PiNode"
            object_input = input_edge_or_unwind(node, :name, "object")
            decompile_body(object_input.from)
            node.decompiled = object_input.from.props[DECOMPILED_PROP]
          when "LoadIndexedNode"
            array_input = input_edge_or_unwind(node, :name, "array")
            index_input = input_edge_or_unwind(node, :name, "index")
            decompile_body(array_input.from)
            decompile_body(index_input.from)
            node.decompiled = "#{array_input.from.decompiled}[#{index_input.from.decompiled}]"
          when "UnboxNode"
            value_input = input_edge_or_unwind(node, :name, "value")
            decompile_body(value_input.from)
            node.props[SKIP_DURING_COLLECTION_PROP] = true
            node.decompiled = "Unbox(#{value_input.from.decompiled})"
          when "BoxNode"
            value_input = input_edge_or_unwind(node, :name, "value")
            decompile_body(value_input.from)
            node.props[SKIP_DURING_COLLECTION_PROP] = true
            node.decompiled = "Box(#{value_input.from.decompiled})"
          when "IsNullNode"
            value_edge = input_edge_or_unwind(node, :name, "value")
            decompile_body(value_edge.from)
            node.decompiled = "#{value_edge.from.decompiled} == null"
          when "InstanceOfNode"
            # willfully ignore these nodes
            value_edge = input_edge_or_unwind(node, :name, "value")
            decompile_body(value_edge.from)
            node.decompiled = "InstanceOf('#{node.props["checkedStamp"]}', #{value_edge.from.decompiled})"
          end

          return if node.decompiled
        end

        # detect binary operands
        data_input_edges = node.inputs.select { |edge| edge.props[:kind] == "data" }
        if node.props[:kind] == "op" && data_input_edges.size == 2
          # TODO: ordering. are we sure that x is always the first edge?
          x, y = data_input_edges
          decompile_body(x.from)
          decompile_body(y.from)
          node.decompiled = "#{x.from.decompiled} #{node.props.dig(:node_class, :name_template)} #{y.from.decompiled}"
        end
      end

      private

      def input_edge_or_unwind(node, prop_key, prop_value)
        if (item = node.inputs.find { |edge| edge.props[prop_key] == prop_value })
          item
        else
          node.failure_reason = "Failed to find input edge with #{prop_key}=#{prop_value}"
          raise Unwind.new(node)
        end
      end

      def output_edge_or_unwind(node, prop_key, prop_value)
        if (item = node.outputs.find { |edge| edge.props[prop_key] == prop_value })
          item
        else
          node.failure_reason = "Failed to find output edge with #{prop_key}=#{prop_value}"
          raise Unwind.new(node)
        end
      end

      def new_var_id
        id = @max_var_id
        @max_var_id += 1
        id
      end

      class Unwind < StandardError
        attr_reader :unsatisfied_dependency

        def initialize(unsatisfied_node)
          @unsatisfied_dependency = [unsatisfied_node]
        end

        def could_not_satisfy_dependency(node)
          @unsatisfied_dependency << node
        end
      end

      class Collector
        def initialize
          @lines = []
          @indent = 0
        end

        def collect(node)
          while node
            node = collect_until_merge(node)
          end

          @lines.join("\n")
        end

        private

        def collect_until_merge(node)
          loop do
            next_node = collect_one(node)
            return finish_line(node) if next_node == :done

            if next_node == :next
              edge = node.outputs.find { |edge| edge.props[:kind] == "control" }
              return finish_line(node) unless edge
              next_node = edge.to
            end

            return next_node if next_node&.props&.dig(:node_class, :node_class)&.end_with?("MergeNode")

            node = next_node
          end
        end

        def finish_line(node)
          add_line("# Stopped at #{node}") unless node.node_class&.end_with?("ReturnNode")
          nil
        end

        def collect_one(node)
          last_part = node.props.dig(:node_class, :node_class)&.split('.')&.last
          return :next if node.props[SKIP_DURING_COLLECTION_PROP]
          if (failure = node.failure_reason)
            add_line("# #{failure}")
            return :done
          end

          case last_part
          when "IfNode"
            true_branch = node.outputs.find { |edge| edge.props[:name] == "trueSuccessor" }
            false_branch = node.outputs.find { |edge| edge.props[:name] == "falseSuccessor" }
            raise "need true branch" unless true_branch
            raise "need false branch" unless false_branch

            merge = nil
            false_branch_merge = nil
            add_decompiled_code(node)
            indent { merge = collect_until_merge(true_branch.to) }
            add_line("else")
            indent { false_branch_merge = collect_until_merge(false_branch.to) }
            add_line("end")

            next_node = merge || false_branch_merge

            if next_node
              next_node
            else
              :done
            end
          else
            add_decompiled_code(node)

            :next
          end
        end

        def add_line(line, node = nil)
          return unless line
          line += " # from #{node}" if node && $DEBUG
          @lines << "#{' ' * @indent}#{line}"
        end

        def add_decompiled_code(node)
          decompiled = node.decompiled
          case decompiled
          when Array
            decompiled.each { |line| add_line(line, node) }
          when String
            add_line(decompiled, node)
          end
        end

        def indent
          @indent += 2
          yield
          @indent -= 2
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
