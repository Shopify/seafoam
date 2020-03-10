module Seafoam
  module Annotators
    # The Graal annotator applies if it looks like it was compiled by Graal or
    # Truffle.
    class GraalAnnotator < Annotator
      def self.applies?(graph)
        graph.props.values.any? do |v|
          TRIGGERS.any? { |t| v.to_s.include?(t) }
        end
      end

      def annotate(graph)
        annotate_nodes graph
        annotate_edges graph
        hide_frame_state graph if @options[:hide_frame_state]
        hide_floating graph if @options[:hide_floating]
        reduce_edges graph if @options[:reduce_edges]
        hide_unused_nodes graph
      end

      private

      # Annotate nodes with their label and kind
      def annotate_nodes(graph)
        graph.nodes.each_value do |node|
          # The Java class of the node.
          node_class = node.props.dig(:node_class, :node_class)

          # IGV renders labels using a template, with parts that are replaced
          # with other properties. We will modify these templates in some
          # cases.
          name_template = node.props.dig(:node_class, :name_template)

          # For constant nodes, the rawvalue is a truncated version of the
          # actual value, which is fully qualified. Instead, produce a simple
          # version of the value and don't truncate it.
          if node_class == 'org.graalvm.compiler.nodes.ConstantNode'
            if node.props['value'] =~ /Object\[Instance<(\w+\.)+(\w*)>\]/
              node.props['rawvalue'] = "instance:#{Regexp.last_match(2)}"
            end
            name_template = 'C({p#rawvalue})'
          end

          # The template for FixedGuardNode could be simpler.
          if %w[
            org.graalvm.compiler.nodes.FixedGuardNode
            org.graalvm.compiler.nodes.GuardNode
          ].include?(node_class)
            name_template = if node.props[:negated]
                              'Guard, else {p#reason/s}'
                            else
                              'Guard not, else {p#reason/s}'
                            end
          end

          # The template for InvokeNode could be simpler.
          if node_class == 'org.graalvm.compiler.nodes.InvokeNode'
            name_template = 'Call {p#targetMethod/s}'
          end

          # The template for InvokeWithExceptionNode could be simpler.
          if node_class == 'org.graalvm.compiler.nodes.InvokeWithExceptionNode'
            name_template = 'Call {p#targetMethod/s} !'
          end

          # The template for CommitAllocationNode could be simpler.
          if node_class == 'org.graalvm.compiler.nodes.virtual.CommitAllocationNode'
            name_template = 'Alloc'
          end

          # The template for org.graalvm.compiler.nodes.virtual.VirtualArrayNode includes an ID that we don't normally need.
          if node_class == 'org.graalvm.compiler.nodes.virtual.VirtualArrayNode'
            name_template = 'VirtualArray {p#componentType/s}[{p#length}]'
          end

          # The template for LoadField could be simpler.
          if node_class == 'org.graalvm.compiler.nodes.java.LoadFieldNode'
            name_template = 'LoadField {x#field}'
          end

          # The template for StoreField could be simpler.
          if node_class == 'org.graalvm.compiler.nodes.java.StoreFieldNode'
            name_template = 'StoreField {x#field}'
          end

          # We want to see keys for IntegerSwitchNode.
          if node_class == 'org.graalvm.compiler.nodes.extended.IntegerSwitchNode'
            name_template = 'IntegerSwitch {p#keys}'
          end

          # Use a symbol for PiNode.
          if node_class == 'org.graalvm.compiler.nodes.PiNode'
            name_template = 'π'
          end

          # Use a symbol for PhiNode.
          if node_class == 'org.graalvm.compiler.nodes.ValuePhiNode'
            name_template = 'ϕ'
          end

          # Better template for frame states.
          if node_class == 'org.graalvm.compiler.nodes.FrameState'
            name_template = 'FrameState {x#state}'
          end

          # Show the stamp in an InstanceOfNode.
          if node_class == 'org.graalvm.compiler.nodes.java.InstanceOfNode'
            name_template = 'InstanceOf {x#simpleStamp}'
          end

          if name_template.empty?
            # If there is no template, then the label is the short name of the
            # Java class, without '...Node' because that's redundant.
            short_name = node_class.split('.').last
            short_name = short_name.slice(0, short_name.size - 'Node'.size) if short_name.end_with?('Node')
            label = short_name
          else
            # Render the template.
            label = render_name_template(name_template, node)
          end

          # Annotate interesting stamps.
          if node.props['stamp'] =~ /(\[\d+ \- \d+\])/
            node.props[:out_annotation] = Regexp.last_match(1)
          end

          # That's our label.
          node.props[:label] = label

          # Set the :kind property.
          if node_class.start_with?('org.graalvm.compiler.nodes.calc.') ||
             node_class.start_with?('org.graalvm.compiler.replacements.nodes.arithmetic.')
            kind = 'calc'
          else
            kind = NODE_KIND_MAP[node_class] || 'other'
          end
          node.props[:kind] = kind
        end
      end

      # Map of node classes to their kind.
      NODE_KIND_MAP = {
        'org.graalvm.compiler.nodes.BeginNode' => 'control',
        'org.graalvm.compiler.nodes.ConstantNode' => 'input',
        'org.graalvm.compiler.nodes.DeoptimizeNode' => 'effect',
        'org.graalvm.compiler.nodes.EndNode' => 'control',
        'org.graalvm.compiler.nodes.extended.IntegerSwitchNode' => 'control',
        'org.graalvm.compiler.nodes.extended.UnsafeMemoryLoadNode' => 'effect',
        'org.graalvm.compiler.nodes.extended.UnsafeMemoryStoreNode' => 'effect',
        'org.graalvm.compiler.nodes.FixedGuardNode' => 'guard',
        'org.graalvm.compiler.nodes.FrameState' => 'info',
        'org.graalvm.compiler.nodes.GuardNode' => 'guard',
        'org.graalvm.compiler.nodes.IfNode' => 'control',
        'org.graalvm.compiler.nodes.InvokeNode' => 'effect',
        'org.graalvm.compiler.nodes.InvokeWithExceptionNode' => 'effect',
        'org.graalvm.compiler.nodes.java.ArrayLengthNode' => 'effect',
        'org.graalvm.compiler.nodes.java.LoadFieldNode' => 'effect',
        'org.graalvm.compiler.nodes.java.LoadIndexedNode' => 'effect',
        'org.graalvm.compiler.nodes.java.MonitorEnterNode' => 'effect',
        'org.graalvm.compiler.nodes.java.MonitorExitNode' => 'effect',
        'org.graalvm.compiler.nodes.java.NewArrayNode' => 'effect',
        'org.graalvm.compiler.nodes.java.NewInstanceNode' => 'effect',
        'org.graalvm.compiler.nodes.java.RawMonitorEnterNode' => 'effect',
        'org.graalvm.compiler.nodes.java.StoreFieldNode' => 'effect',
        'org.graalvm.compiler.nodes.java.StoreIndexedNode' => 'effect',
        'org.graalvm.compiler.nodes.KillingBeginNode' => 'control',
        'org.graalvm.compiler.nodes.LoopBeginNode' => 'control',
        'org.graalvm.compiler.nodes.LoopEndNode' => 'control',
        'org.graalvm.compiler.nodes.LoopExitNode' => 'control',
        'org.graalvm.compiler.nodes.memory.ReadNode' => 'effect',
        'org.graalvm.compiler.nodes.memory.WriteNode' => 'effect',
        'org.graalvm.compiler.nodes.MergeNode' => 'control',
        'org.graalvm.compiler.nodes.ParameterNode' => 'input',
        'org.graalvm.compiler.nodes.PrefetchAllocateNode' => 'effect',
        'org.graalvm.compiler.nodes.ReturnNode' => 'control',
        'org.graalvm.compiler.nodes.StartNode' => 'control',
        'org.graalvm.compiler.nodes.UnwindNode' => 'effect',
        'org.graalvm.compiler.nodes.virtual.AllocatedObjectNode' => 'virtual',
        'org.graalvm.compiler.nodes.virtual.CommitAllocationNode' => 'effect',
        'org.graalvm.compiler.nodes.virtual.VirtualArrayNode' => 'virtual',
        'org.graalvm.compiler.nodes.VirtualObjectState' => 'info',
        'org.graalvm.compiler.replacements.nodes.ArrayEqualsNode' => 'effect',
        'org.graalvm.compiler.replacements.nodes.ReadRegisterNode' => 'effect',
        'org.graalvm.compiler.replacements.nodes.WriteRegisterNode' => 'effect'

        # org.graalvm.compiler.word.WordCastNode is not an effect even though it is fixed.
      }

      # Render a Graal 'name template'.
      def render_name_template(template, node)
        # {p#name} is replaced with the value of the name property. {i#name} is
        # replaced with the ids of input nodes with edges named name. We
        # probably need to do these replacements in one pass...
        string = template
        string = string.gsub(%r{\{p#(\w+)(/s)?\}}) { |_| node.props[Regexp.last_match(1)] }
        string = string.gsub(%r{\{i#(\w+)(/s)?\}}) { |_| node.inputs.filter { |e| e.props[:name] == Regexp.last_match(1) }.map { |e| e.from.id }.join(', ') }
        string = string.gsub(/\{x#field\}/) { |_| "#{node.props.dig('field', :field_class).split('.').last}.#{node.props.dig('field', :name)}" }
        string = string.gsub(/\{x#state\}/) { |_| "#{node.props.dig('code', :declaring_class)}##{node.props.dig('code', :method_name)} #{node.props['sourceFile']}:#{node.props['sourceLine']}" }
        string = string.gsub(/\{x#simpleStamp\}/) do |_|
          stamp = node.props.dig('checkedStamp')
          if stamp =~ /a!?# L(.*);/
            Regexp.last_match(1)
          else
            stamp
          end
        end
        string
      end

      # Annotate edges with their label and kind.
      def annotate_edges(graph)
        graph.edges.each do |edge|
          if edge.to.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.ValuePhiNode' && edge.props[:name] == 'values'
            merge_node = edge.to.edges.find { |e| e.props[:name] == 'merge' }.from
            control_into_merge = %w[ends loopBegin]
            merge_node_control_edges_in = merge_node.edges.filter { |e| control_into_merge.include?(e.props[:name]) && e.to.props.dig(:node_class, :node_class) != 'org.graalvm.compiler.nodes.LoopExitNode' }
            matching_control_edge = merge_node_control_edges_in[edge.props[:index]]
            control_in_node = matching_control_edge.nodes.find { |n| n != merge_node }
            edge.props[:label] = "from #{control_in_node.id}"
            edge.props[:kind] = 'data'
            next
          end

          # Look at the name of the edge to decide how to treat them.
          case edge.props[:name]

          # Control edges.
          when 'ends', 'next', 'trueSuccessor', 'falseSuccessor', 'exceptionEdge'
            edge.props[:kind] = 'control'
            case edge.props[:name]
            when 'trueSuccessor'
              # Simplify trueSuccessor to T
              edge.props[:label] = 'T'
            when 'falseSuccessor'
              # Simplify falseSuccessor to F
              edge.props[:label] = 'F'
            when 'exceptionEdge'
              # Simplify exceptionEdge to unwind
              edge.props[:label] = 'unwind'
            end

          # Info edges, which are drawn reversed as they point from the user
          # to the info.
          when 'frameState', 'callTarget', 'stateAfter'
            edge.props[:label] = nil
            edge.props[:kind] = 'info'
            edge.props[:reverse] = true

          # Condition for branches, which we label as ?.
          when 'condition'
            edge.props[:kind] = 'data'
            edge.props[:label] = '?'

          # loopBegin edges point from LoopEndNode (continue) and LoopExitNode
          # (break) to the LoopBeginNode. Both are drawn reversed.
          when 'loopBegin'
            edge.props[:hidden] = true

            case edge.to.props.dig(:node_class, :node_class)
            when 'org.graalvm.compiler.nodes.LoopEndNode'
              # If it's from the LoopEnd then it's the control edge to follow.
              edge.props[:kind] = 'loop'
              edge.props[:reverse] = true
            when 'org.graalvm.compiler.nodes.LoopExitNode'
              # If it's from the LoopExit then it's just for information - it's
              # not control flow to follow.
              edge.props[:kind] = 'info'
              edge.props[:reverse] = true
            else
              raise EncodingError, 'loopBegin edge not to LoopEnd or LoopExit'
            end

          # Merges are info.
          when 'merge'
            edge.props[:kind] = 'info'
            edge.props[:reverse] = true

          # Successors are control from a switch.
          when 'successors'
            # We want to label the edges with the corresponding index of the key.
            if edge.props[:index] == edge.from.props['keys'].size
              label = 'default'
            else
              label = "k[#{edge.props[:index]}]"
            end
            edge.props[:label] = label
            edge.props[:kind] = 'control'

          # Successors are control from a switch.
          when 'arguments'
            # We want to label the edges with their corresponding argument index.
            edge.props[:label] = "arg[#{edge.props[:index]}]"
            edge.props[:kind] = 'data'

          # Everything else is data.
          else
            edge.props[:kind] = 'data'
            edge.props[:label] = edge.props[:name]

          end
        end
      end

      # Hide frame state nodes. These are for deoptimisation, are rarely
      # useful to look at, and severely clutter the graph.
      def hide_frame_state(graph)
        graph.nodes.each_value do |node|
          if FRAME_STATE_NODES.include?(node.props.dig(:node_class, :node_class))
            node.props[:hidden] = true
          end
        end
      end

      # Hide floating nodes. This highlights just the control flow backbone.
      def hide_floating(graph)
        graph.nodes.each_value do |node|
          if node.edges.none? { |e| e.props[:kind] == 'control' }
            node.props[:hidden] = true
          end
        end
      end

      # Reduce edges to simple constants and parameters by inlining them. An
      # inlined node is one that is shown each time it is used, just above the
      # using node. This reduces very long edges all across the graph. We inline
      # nodes that are 'simple', like parameters and constants.
      def reduce_edges(graph)
        graph.nodes.each_value do |node|
          if SIMPLE_INPUTS.include?(node.props.dig(:node_class, :node_class))
            node.props[:inlined] = true
          end
        end
      end

      # Hide nodes that have no non-hidden users and no control flow in. These
      # would display as a node floating unconnected to the rest of the graph
      # otherwise. An exception is made for node with an anchor edge coming in,
      # as some guards are anchored like this.
      def hide_unused_nodes(graph)
        loop do
          modified = false
          graph.nodes.each_value do |node|
            next unless node.outputs.all? { |edge| edge.to.props[:hidden] } &&
                node.inputs.none? { |edge| edge.props[:kind] == 'control' } &&
                node.inputs.none? { |edge| edge.props[:name] == 'anchor' }
            unless node.props[:hidden]
              node.props[:hidden] = true
              modified = true
            end
          end
          break unless modified
        end
      end

      # If we see these in the graph properties it's probably a Graal graph.
      TRIGGERS = %w[
        GraalCompiler
        TruffleCompilerThread
      ]

      # Simple input node classes that may be inlined.
      SIMPLE_INPUTS = %w[
        org.graalvm.compiler.nodes.ConstantNode
        org.graalvm.compiler.nodes.ParameterNode
      ]

      # Nodes just to maintain frame state.
      FRAME_STATE_NODES = %w[
        org.graalvm.compiler.nodes.FrameState
        org.graalvm.compiler.virtual.nodes.MaterializedObjectState
      ]
    end
  end
end
