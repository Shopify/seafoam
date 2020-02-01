#!/usr/bin/env ruby

require 'seafoam'

require 'benchmark/ips'

# This benchmark measures how long it takes to render a graph.

BGV_FILE = File.expand_path('../examples/matmult-java.bgv', __dir__)

graph = File.open(BGV_FILE) do |stream|
  parser = Seafoam::BGVParser.new(stream)
  parser.read_file_header
  parser.read_graph_preheader
  parser.read_graph_header
  parser.read_graph
end

Benchmark.ips do |x|
  x.report('render') do
    out = StringIO.new
    writer = Seafoam::GraphvizWriter.new(out)
    writer.write_graph graph
  end
end
