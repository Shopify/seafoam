module Seafoam
  module Formatters
    module Text
      # A plain-text formatter for the `describe` command.
      class DescribeFormatter < Seafoam::Formatters::Base::DescribeFormatter
        def format
          notes = Seafoam::Graal::GraphDescription::ATTRIBUTES.select { |attr| description.send(attr) }
          node_counts = description.sorted_node_counts.map { |node_class, count| "#{node_class}: #{count}" }.join("\n")

          ["#{graph.nodes.size} nodes", *notes].join(', ') + "\n#{node_counts}"
        end
      end

      # A plain-text formatter for the `edges` command.
      class EdgesFormatter < Seafoam::Formatters::Base::EdgesFormatter
        def render_edges_entry(edges)
          edges.map do |edge|
            "#{edge.from.id_and_label} ->(#{edge.props[:label]}) #{edge.to.id_and_label}"
          end.join("\n")
        end

        def render_node_entry(node)
          ret = ['Input:']
          ret += node.inputs.map do |input|
            "  #{node.id_and_label} <-(#{input.props[:label]}) #{input.from.id_and_label}"
          end

          ret << 'Output:'
          ret += node.outputs.map do |output|
            "  #{node.id_and_label} ->(#{output.props[:label]}) #{output.to.id_and_label}"
          end

          ret.join("\n")
        end

        def render_summary_entry(node_count, edge_count)
          "#{node_count} nodes, #{edge_count} edges"
        end
      end

      # A plain-text formatter for the `info` command.
      class InfoFormatter < Seafoam::Formatters::Base::InfoFormatter
        def format
          "BGV #{major_version}.#{minor_version}"
        end
      end

      # A plain-text formatter for the `list` command.
      class ListFormatter < Seafoam::Formatters::Base::ListFormatter
        def format
          entries.map do |entry|
            "#{entry.file}:#{entry.index}  #{entry.graph_name_components.join('/')}"
          end.join("\n")
        end
      end

      # A plain-text formatter for the `source` command.
      class SourceFormatter < Seafoam::Formatters::Base::SourceFormatter
        def format
          Seafoam::Graal::Source.walk(source_position, &method(:render_method)).join("\n")
        end

        def render_method(method)
          declaring_class = method[:declaring_class]
          name = method[:method_name]
          "#{declaring_class}##{name}"
        end
      end
    end
  end
end
