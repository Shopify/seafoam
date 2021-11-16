module Seafoam
  module Formatters
    module Text
      # A plain-text formatter for the `info` command.
      class InfoFormatter < Seafoam::Formatters::Base::InfoFormatter
        def format
          "BGV #{major_version}.#{minor_version}"
        end
      end
    end
  end
end
