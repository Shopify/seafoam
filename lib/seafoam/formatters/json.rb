require 'json'

module Seafoam
  module Formatters
    module Json
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
    end
  end
end
