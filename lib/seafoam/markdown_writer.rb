# frozen_string_literal: true

module Seafoam
  # A writer from graphs to Markdown format, with an embedded Mermaid graph.
  class MarkdownWriter
    def initialize(stream)
      @stream = stream
    end

    # Write a graph.
    def write_graph(graph)
      @stream.puts "```mermaid"
      mermaid = MermaidWriter.new(@stream)
      mermaid.write_graph(graph)
      @stream.puts "```"
    end
  end
end
