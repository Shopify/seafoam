module Seafoam
  module Passes
    # The fallback pass always applies, and adds some basic properties.
    # Works for example with Truffle AST and call graphs, but also means anyone
    # can emit a graph with 'label' properties and we can do something useful
    # with it.
    class FallbackPass < Pass
      def self.applies?(_graph)
        true
      end

      def apply(graph)
        graph.nodes.each_value do |node|
          if node.props[:label].nil? && node.props['label']
            node.props[:label] = node.props['label']
          end

          node.props[:kind] ||= 'other'
        end

        graph.edges.each do |edge|
          edge.props[:kind] ||= 'other'
        end
      end
    end
  end
end
