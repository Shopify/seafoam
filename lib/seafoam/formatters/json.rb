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
    end
  end
end
