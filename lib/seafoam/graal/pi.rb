# frozen_string_literal: true

module Seafoam
  module Graal
    # Routines for understanding pi nodes in Graal.
    module Pi
      class << self
        # Find the actual value behind potentially a chain of pi nodes.
        def follow_pi_object(node)
          node = node.edges.find { |edge| edge.props[:name] == "object" }.from while PI_NODES.include?(node.node_class)
          node
        end
      end

      # Pi nodes add type information.
      PI_NODES = [
        "org.graalvm.compiler.nodes.PiNode",
        "org.graalvm.compiler.nodes.PiArrayNode",
        "jdk.graal.compiler.nodes.PiNode",
        "jdk.graal.compiler.nodes.PiArrayNode",
      ]
    end
  end
end
