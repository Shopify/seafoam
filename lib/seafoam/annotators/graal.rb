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
        hide_detached_nodes graph
      end

      private

      # Annotate nodes with their label and kind
      def annotate_nodes(graph)
        graph.nodes.each_value do |node|
          # The Java class of the node.
          node_class = node.props.dig(:node_class, :node_class)

          # For constant nodes, the rawvalue is a truncated version of the
          # actual value, which is fully qualified. Instead, produce a simple
          # version of the value and don't truncate it.
          if node_class == 'org.graalvm.compiler.nodes.ConstantNode'
            if node.props['value'] =~ /Object\[Instance<(\w+\.)+(\w*)>\]/
              node.props['rawvalue'] = "Object[Instance<#{Regexp.last_match(2)}>]"
            end
          end

          # IGV renders labels using a template, with parts that are replaced
          # with other properties. We will modify these templates in some
          # cases.
          name_template = node.props.dig(:node_class, :name_template)

          # The template for FixedGuardNode could be simpler.
          if node_class == 'org.graalvm.compiler.nodes.FixedGuardNode'
            name_template = if node.props[:negated]
                              'Guard not, or {p#reason/s}'
                            else
                              'Guard, or {p#reason/s}'
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

          # Use a symbol for PiNode
          if node_class == 'org.graalvm.compiler.nodes.PiNode'
            name_template = 'π'
          end

          # Use a symbol for PhiNode.
          if node_class == 'org.graalvm.compiler.nodes.ValuePhiNode'
            name_template = 'ϕ({i#values}, {p#valueDescription})'
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

          # That's our label.
          node.props[:label] = label

          # Set the :kind property.
          if node_class.start_with?('org.graalvm.compiler.nodes.calc.')
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
        'org.graalvm.compiler.nodes.FixedGuardNode' => 'effect',
        'org.graalvm.compiler.nodes.FrameState' => 'info',
        'org.graalvm.compiler.nodes.IfNode' => 'control',
        'org.graalvm.compiler.nodes.InvokeNode' => 'effect',
        'org.graalvm.compiler.nodes.InvokeWithExceptionNode' => 'effect',
        'org.graalvm.compiler.nodes.java.LoadIndexedNode' => 'effect',
        'org.graalvm.compiler.nodes.java.StoreIndexedNode' => 'effect',
        'org.graalvm.compiler.nodes.LoopBeginNode' => 'control',
        'org.graalvm.compiler.nodes.LoopEndNode' => 'control',
        'org.graalvm.compiler.nodes.LoopExitNode' => 'control',
        'org.graalvm.compiler.nodes.ParameterNode' => 'input',
        'org.graalvm.compiler.nodes.ReturnNode' => 'control',
        'org.graalvm.compiler.nodes.StartNode' => 'control',
        'org.graalvm.compiler.nodes.VirtualObjectState' => 'info'
      }

      # Render a Graal 'name template'.
      def render_name_template(template, node)
        # {p#name} is replaced with the value of the name property. {i#name} is
        # replaced with the ids of input nodes with edges named name. We
        # probably need to do these replacements in one pass...
        string = template
        string = string.gsub(%r{\{p#(\w+)(/s)?\}}) { |_| node.props[Regexp.last_match(1)] }
        string = string.gsub(%r{\{i#(\w+)(/s)?\}}) { |_| node.inputs.filter { |e| e.props[:name] == Regexp.last_match(1) }.map { |e| e.from.id }.join(', ') }
        string
      end

      # Annotate edges with their label and kind.
      def annotate_edges(graph)
        graph.edges.each do |edge|
          # Look at the name of the edge to decide how to treat them.
          case edge.props[:name]

          # Control edges.
          when 'ends', 'next', 'trueSuccessor', 'falseSuccessor'
            edge.props[:kind] = 'control'
            case edge.props[:name]
            when 'trueSuccessor'
              # Simplify trueSuccessor to T
              edge.props[:label] = 'T'
            when 'falseSuccessor'
              # Simplify falseSuccessor to F
              edge.props[:label] = 'F'
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

      # Hide nodes that have no non-hidden edges. These would display as a node
      # floating unconnected to the rest of the graph otherwise.
      def hide_detached_nodes(graph)
        graph.nodes.each_value do |node|
          if node.adjacent.all? { |n| n.props[:hidden] }
            node.props[:hidden] = true
          end
        end
      end

      # If we see these in the graph properties it's probably a Graal graph.
      TRIGGERS = %w[
        GraalCompiler
        TruffleCompilerThread
      ]

      # Simple input node classes that may be inlined.
      SIMPLE_INPUTS = [
        'org.graalvm.compiler.nodes.ConstantNode',
        'org.graalvm.compiler.nodes.ParameterNode'
      ]

      # Nodes just to maintain frame state.
      FRAME_STATE_NODES = [
        'org.graalvm.compiler.nodes.FrameState',
        'org.graalvm.compiler.nodes.virtual.VirtualArrayNode',
        'org.graalvm.compiler.virtual.nodes.MaterializedObjectState',
        'org.graalvm.compiler.virtual.nodes.VirtualObjectState'
      ]
    end
  end
end
