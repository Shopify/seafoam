module Seafoam
  module Annotators
    # The fallback annotator always applies, and adds some basic annotations.
    # Works for example with Truffle AST and call graphs, but also means anyone
    # can emit a graph with 'label' properties and we can do something useful
    # with it.
    class FallbackAnnotator < Annotator
      def self.applies?(_graph)
        true
      end

      def annotate(graph)
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
