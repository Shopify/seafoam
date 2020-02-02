module Seafoam
  class Dominator
    def initialize(graph)
      @graph = graph
      @dominates = Hash.new { |hash, key|
        a, b = key
        dominates = solve(a, b)
        hash[key] = dominates
      }
    end

    def dominates?(a, b)
      key = [a, b]
      @dominates[key]
    end

    private

    def solve(a, b)
      control_in = b.inputs.select { |edge| edge.props[:kind] == 'control' }.map(&:from)
      if control_in.include?(a)
        # If a has a control edge to b then a dominates b
        true
      elsif control_in.empty?
        # If b is the start node then a cannot dominate b
        false
      else
        # a dominates b if a dominates all inputs to b
        control_in.all? { |node| dominates?(a, node) }
      end
    end
  end
end
