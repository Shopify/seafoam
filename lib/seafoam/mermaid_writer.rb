module Seafoam
  # A writer from graphs to the Mermaid format.
  class MermaidWriter
    def initialize(stream)
      @stream = stream
    end

    # Write a graph.
    def write_graph(graph)
      @stream.puts 'flowchart TD'
      write_nodes graph
      write_edges graph
    end

    private

    # Write node declarations.
    def write_nodes(graph)
      graph.nodes.each_value do |node|
        write_node node
      end
    end

    def write_node(node)
      @stream.puts "  node#{node.id}[#{node.props[:label].inspect}]"
    end

    # Write edge declarations.

    def write_edges(graph)
      graph.edges.each do |edge|
        write_edge edge
      end
    end

    def write_edge(edge)
      @stream.puts "  node#{edge.from.id} --> node#{edge.to.id}"
    end
  end
end
