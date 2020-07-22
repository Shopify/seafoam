module Seafoam
  module SpecHelpers
    SAMPLE_BGV = [
      'fib-java.bgv',
      'fib-js.bgv',
      'fib-ruby.bgv',
      'matmult-java.bgv',
      'matmult-ruby.bgv'
    ].map { |f| File.expand_path("../../examples/#{f}", __dir__) }

    def self.example_graph(file, graph_index)
      file = File.expand_path("../../examples/#{file}.bgv", __dir__)
      parser = Seafoam::BGVParser.new(File.new(file))
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
  end
end
