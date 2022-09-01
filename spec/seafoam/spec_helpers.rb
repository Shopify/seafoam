# frozen_string_literal: true

module Seafoam
  module SpecHelpers
    SAMPLE_BGV = [
      "fib-java.bgv.gz",
      "fib-js.bgv.gz",
      "fib-ruby.bgv.gz",
    ].map { |f| File.expand_path("../../examples/graalvm-ce-java11-21.2.0/#{f}", __dir__) }

    def self.example_graph(file, graph_index)
      unless File.exist?(file)
        file = File.expand_path("../../examples/graalvm-ce-java11-21.2.0/#{file}.bgv.gz", __dir__)
      end
      parser = Seafoam::BGV::BGVParser.new(file)
      parser.read_file_header
      parser.skip_document_props
      loop do
        index, = parser.read_graph_preheader
        raise unless index

        if index == graph_index
          parser.read_graph_header
          break parser.read_graph
        else
          parser.skip_graph_header
          parser.skip_graph
        end
      end
    end

    def self.dependencies_installed?
      ENV["NO_DEPENDENCIES_INSTALLED"].nil?
    end
  end
end
