module Seafoam
  # Spotlight can *light* nodes, which makes them visible, their adjacent nodes
  # visible by grey, and other nodes invisible. Multiple nodes can be *lit*.
  class Spotlight
    def initialize(graph)
      @graph = graph
    end

    # Mark a node as lit by the spotlight.
    def light(node)
      # This node is lit.
      node.props[:spotlight] = 'lit'

      # Adjacent nodes are shaded, if they haven't be lit themselvs.
      node.adjacent.each do |adjacent|
        adjacent.props[:spotlight] ||= 'shaded'
      end
    end

    # Go through all other nodes and make them hidden, having lit as many nodes
    # as you want.
    def shade
      @graph.nodes.each_value do |node|
        node.props[:hidden] = true unless node.props[:spotlight]
      end
    end
  end
end
