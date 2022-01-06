module Seafoam
  module Formatters
    module Base
      # Base interface for all formatters. Returns a string representation of the associated command's output.
      module Formatter
        def format
          raise NotImplementedError
        end
      end

      # Formats the output of the `describe` command.
      class DescribeFormatter
        include Formatter

        attr_reader :graph, :description

        def initialize(graph, description)
          @graph = graph
          @description = description
        end
      end

      # Formats the output of the `edges` command.
      class EdgesFormatter
        include Formatter

        EdgesEntry = Struct.new(:edges) do
          def render(formatter)
            formatter.render_edges_entry(edges)
          end
        end

        NodeEntry = Struct.new(:node) do
          def render(formatter)
            formatter.render_node_entry(node)
          end
        end

        SummaryEntry = Struct.new(:node_count, :edge_count) do
          def render(formatter)
            formatter.render_summary_entry(node_count, edge_count)
          end
        end

        attr_reader :entry

        def initialize(entry)
          @entry = entry
        end

        def format
          entry.render(self)
        end

        def render_edges_entry(edges)
          raise NotImplementedError
        end

        def render_node_entry(node)
          raise NotImplementedError
        end

        def render_summary_entry(node_count, edge_count)
          raise NotImplementedError
        end
      end

      # Formats the output of the `info` command.
      class InfoFormatter
        include Formatter

        attr_reader :major_version, :minor_version

        def initialize(major_version, minor_version)
          @major_version = major_version
          @minor_version = minor_version
        end
      end

      # Formats the output of the `list` command.
      class ListFormatter
        include Formatter

        Entry = Struct.new(:file, :graph_name_components, :index)

        attr_reader :entries

        def initialize(entries)
          @entries = entries
        end
      end

      # Formats the output of the `source` command.
      class SourceFormatter
        include Formatter

        attr_reader :source_position

        def initialize(source_position)
          @source_position = source_position
        end
      end
    end
  end
end
