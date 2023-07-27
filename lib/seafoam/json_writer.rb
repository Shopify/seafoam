# frozen_string_literal: true

require "json"

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
          props: node.props,
        )

        node.outputs.each do |edge|
          edges.push(
            from: edge.from.id,
            to: edge.to.id,
            props: edge.props,
          )
        end
      end

      object = {
        name: name,
        props: graph.props,
        nodes: nodes,
        edges: edges,
      }

      @out.puts JSON.pretty_generate(prepare_json(object))
    end

    def self.prepare_json(object)
      case object
      when Float
        if object.nan?
          "[NaN]"
        else
          object
        end
      when Array
        object.map { |o| prepare_json(o) }
      when Hash
        object.transform_values { |v| prepare_json(v) }
      else
        object
      end
    end
  end
end
