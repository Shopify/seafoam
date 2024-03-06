# frozen_string_literal: true

module Seafoam
  module SpecHelpers
    SAMPLE_BGV = [
      "fib-java.bgv.gz",
      "fib-js.bgv.gz",
      "fib-ruby.bgv.gz",
    ].map { |f| File.expand_path("../../examples/graalvm-ce-java11-21.2.0/#{f}", __dir__) }

    class << self
      def example_graph(file, graph_index)
        unless File.exist?(file)
          file = File.expand_path("../../examples/graalvm-ce-java11-21.2.0/#{file}.bgv.gz", __dir__)
        end
        parser = Seafoam::BGV::BGVParser.new(file)
        parser.read_file_header
        parser.skip_document_props
        loop do
          index, = parser.read_graph_preheader
          raise unless index

          if graph_index.is_a?(Integer) && index == graph_index
            parser.read_graph_header
            break parser.read_graph
          else
            graph_header = parser.read_graph_header
            graph_name = parser.graph_name(graph_header)

            if graph_index == graph_name.last
              break parser.read_graph
            end

            parser.skip_graph
          end
        end
      end

      def dependencies_installed?
        ENV["NO_DEPENDENCIES_INSTALLED"].nil?
      end
    end
  end
end
