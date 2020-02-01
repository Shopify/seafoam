#!/usr/bin/env ruby

require 'seafoam'

require 'benchmark/ips'

# This benchmark compares throughput of fully reading a graph file, compared
# to, as best as possible, seeking through it.

BGV_FILE = File.expand_path('../examples/matmult-java.bgv', __dir__)

Benchmark.ips do |x|
  x.report('read') do
    File.open(BGV_FILE) do |stream|
      parser = Seafoam::BGVParser.new(stream)
      parser.read_file_header
      loop do
        index, = parser.read_graph_preheader
        break unless index

        parser.read_graph_header
        parser.read_graph
      end
    end
  end

  x.report('seek') do
    File.open(BGV_FILE) do |stream|
      parser = Seafoam::BGVParser.new(stream)
      parser.read_file_header
      loop do
        index, = parser.read_graph_preheader
        break unless index

        parser.skip_graph_header
        parser.skip_graph
      end
    end
  end

  x.compare!
end
