module Seafoam
  # Can tell you if one node dominates another node.
  class Dominator
    def initialize(graph)
      @graph = graph
      @dominates = Hash.new do |hash, key|
        node_a, node_b = key
        dominates = solve(node_a, node_b)
        hash[key] = dominates
      end
    end

    def dominates?(node_a, node_b)
      key = [node_a, node_b]
      @dominates[key]
    end

    private

    def solve(node_a, node_b)
      control_in = node_b.inputs.select { |edge| edge.props[:kind] == 'control' }.map(&:from)
      if control_in.include?(node_a)
        # If a has a control edge to b then a dominates b
        true
      elsif control_in.empty?
        # If b is the start node then a cannot dominate b
        false
      else
        # a dominates b if a dominates all inputs to b
        control_in.all? { |node| dominates?(node_a, node) }
      end
    end
  end
end
