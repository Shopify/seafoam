#!/usr/bin/env ruby

require 'seafoam'

# This benchmark measures the time taken by the external dot Graphviz program
# to render to PDF.

Dir.glob(File.expand_path('../examples/*.bgv', __dir__)).each do |file|
  File.open(file) do |stream|
    parser = Seafoam::BGVParser.new(stream)
    parser.read_file_header
    loop do
      index, = parser.read_graph_preheader
      break unless index

      parser.read_graph_header
      graph = parser.read_graph

      annotator_options = {
        hide_frame_state: true,
        hide_floating: false,
        reduce_edges: true
      }

      Seafoam::Annotators.apply graph, annotator_options

      File.open('out.dot', 'w') do |dot_stream|
        writer = Seafoam::GraphvizWriter.new(dot_stream)
        writer.write_graph graph
      end

      print "#{file}:#{index} (#{graph.nodes.size} nodes, #{graph.edges.size} edges)... "

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      `dot -Tpdf --out out.pdf out.dot`
      finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      puts format('%.2fs', finish - start)
    end
  end
end
