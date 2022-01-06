module Seafoam
  module Formatters
    module Text
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
