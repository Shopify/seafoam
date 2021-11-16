module Seafoam
  module Formatters
    module Base
      # Base interface for all formatters. Returns a string representation of the associated command's output.
      module Formatter
        def format
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
    end
  end
end
