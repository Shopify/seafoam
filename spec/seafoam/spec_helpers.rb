module Seafoam
  module SpecHelpers
    @graph_cache = {}

    def self.example_graph(file, graph_index)
      @graph_cache[[file, graph_index]] ||= load_example_graph(file, graph_index)
    end

    def self.load_example_graph(file, graph_index)
        File.open(File.expand_path("../../examples/#{file}.bgv", __dir__)) do |stream|
          parser = Seafoam::BGVParser.new(stream)
          parser.read_file_header
          loop do
            index, = parser.read_graph_preheader
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
end
