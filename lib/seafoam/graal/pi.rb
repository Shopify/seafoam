module Seafoam
  module Graal
    # Routines for understanding pi nodes in Graal.
    module Pi
      # Find the actual value behind potentially a chain of pi nodes.
      def self.follow_pi_object(node)
        node = node.edges.find { |edge| edge.props[:name] == 'object' }.from while PI_NODES.include?(node.props.dig(:node_class, :node_class))
        node
      end

      # Pi nodes add type information.
      PI_NODES = [
        'org.graalvm.compiler.nodes.PiNode',
        'org.graalvm.compiler.nodes.PiArrayNode'
      ]
    end
  end
end
