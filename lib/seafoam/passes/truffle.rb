module Seafoam
  module Passes
    # The Truffle pass applies if it looks like it was compiled by Truffle.
    class TrufflePass < Pass
      def self.applies?(graph)
        graph.props.values.any? do |v|
          TRIGGERS.any? { |t| v.to_s.include?(t) }
        end
      end

      def apply(graph)
        simplify_truffle_args graph if @options[:simplify_truffle_args]
      end

      private

      # Simplify a Truffle argument load into a single, inlined, node very much
      # like a Graal parameter node.
      def simplify_truffle_args(graph)
        graph.nodes.dup.each_value do |node|
          next unless node.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.java.LoadIndexedNode'

          index_node = node.inputs.find { |edge| edge.props[:name] == 'index' }.from
          array_node = Graal::Pi.follow_pi_object(node.inputs.find { |edge| edge.props[:name] == 'array' }.from)

          next unless index_node.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.ConstantNode'
          next unless array_node.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.ParameterNode'

          node.props[:truffle_arg_load] = true

          index = index_node.props['rawvalue']

          arg_node = graph.create_node(graph.new_id, { synthetic: true, inlined: true, label: "T(#{index})", kind: 'input' })

          node.outputs.each do |output|
            next if output.props[:name] == 'next'

            graph.create_edge arg_node, output.to, output.props.dup
            graph.remove_edge output
          end
        end

        graph.nodes.each_value.select { |node| node.props[:truffle_arg_load] }.each do |node|
          control_in = node.inputs.find { |edge| edge.props[:name] == 'next' }
          control_out = node.outputs.find { |edge| edge.props[:name] == 'next' }
          graph.create_edge control_in.from, control_out.to, { name: 'next' }
          graph.remove_edge control_in
          graph.remove_edge control_out
        end
      end

      # If we see these in the graph properties it's probably a Truffle graph.
      TRIGGERS = %w[
        TruffleCompiler
      ]
    end
  end
end
