# frozen_string_literal: true

module Seafoam
  # A writer from graphs to the Mermaid format. Re-uses the Graphviz writer,
  # just adapting for the syntax. Attributes are cherry-picked, and more
  # things are left to defaults.
  class MermaidWriter < GraphvizWriter
    def initialize(*args)
      super(*args)
      @link_style_counter = 0
    end

    protected

    def start_graph(_attrs)
      # Ignore bgcolor, as I can't figure out how to do it in Mermaid
      @stream.puts "flowchart TD"
    end

    def end_graph
      # Nothing to do
    end

    def start_subgraph(id)
      @stream.puts "  subgraph B#{id}"
    end

    def end_subgraph
      @stream.puts "  end"
    end

    def output_node(indent, id, attrs)
      case attrs[:shape]
      when "rectangle"
        shape = ["(", ")"]
      when "oval"
        shape = ["([", "])"]
      when "diamond"
        shape = ["{{", "}}"]
      end
      @stream.puts "#{indent}#{id}#{shape[0]}#{attrs[:label].gsub('"', "#quot;").inspect}#{shape[1]}"
      @stream.puts "#{indent}style #{id} fill:#{attrs[:fillcolor]},stroke:#{attrs[:color]},color:#{attrs[:fontcolor]};"
    end

    def output_edge(from, to, attrs)
      @stream.puts "  #{from} --> #{to}"
      link_counter = (@link_style_counter += 1) - 1
      penwidth = attrs[:penwidth]
      @stream.puts "  linkStyle #{link_counter} stroke:#{attrs[:color]},stroke-width:#{penwidth}px;"
    end
  end
end
