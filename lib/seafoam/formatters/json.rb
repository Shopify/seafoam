require 'json'

module Seafoam
  module Formatters
    module Json
      # A JSON-based formatter for the `describe` command.
      class DescribeFormatter < Seafoam::Formatters::Base::DescribeFormatter
        def format
          ret = Seafoam::Graal::GraphDescription::ATTRIBUTES.map { |attr| [attr, description.send(attr)] }.to_h
          ret[:node_count] = graph.nodes.size
          ret[:node_counts] = description.sorted_node_counts

          ret.to_json
        end
      end

      # A JSON-based formatter for the `edges` command.
      class EdgesFormatter < Seafoam::Formatters::Base::EdgesFormatter
        def render_edges_entry(edges)
          edges.map { |edge| build_edge(edge) }.to_json
        end

        def render_node_entry(node)
          {
            input: node.inputs.map { |input| build_edge(input) },
            output: node.outputs.map { |output| build_edge(output) }
          }.to_json
        end

        def render_summary_entry(node_count, edge_count)
          { node_count: node_count, edge_count: edge_count }.to_json
        end

        def build_node(node)
          { id: node.id.to_s, label: node.props[:label] }
        end

        def build_edge(edge)
          { from: build_node(edge.from), to: build_node(edge.to), label: edge.props[:label] }
        end
      end

      # A JSON-based formatter for the `info` command.
      class InfoFormatter < Seafoam::Formatters::Base::InfoFormatter
        def format
          {
            major_version: major_version,
            minor_version: minor_version
          }.to_json
        end
      end

      # A JSON-based formatter for the `list` command.
      class ListFormatter < Seafoam::Formatters::Base::ListFormatter
        def format
          entries.map do |entry|
            {
              graph_index: entry.index,
              graph_file: entry.file,
              graph_name_components: entry.graph_name_components
            }
          end.to_json
        end
      end

      # A JSON-based formatter for the `source` command.
      class SourceFormatter < Seafoam::Formatters::Base::SourceFormatter
        def format
          Seafoam::Graal::Source.walk(source_position, &method(:render_method)).to_json
        end

        def render_method(method)
          declaring_class = method[:declaring_class]
          name = method[:method_name]
          {
            class: declaring_class,
            method: name
          }
        end
      end
    end
  end
end
