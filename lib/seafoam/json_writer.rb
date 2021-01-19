require 'json'

module Seafoam
  # Write files in a JSON format.
  class JSONWriter
    def initialize(out)
      @out = out
    end

    def write(name, graph)
      nodes = []
      edges = []

      graph.nodes.each_value do |node|
        nodes.push(
          id: node.id,
          props: node.props
        )

        node.outputs.each do |edge|
          edges.push(
            from: edge.from.id,
            to: edge.to.id,
            props: edge.props
          )
        end
      end

      object = {
        name: name,
        props: graph.props,
        nodes: nodes,
        edges: edges
      }

      @out.puts JSON.generate(object)
    end
  end
end
