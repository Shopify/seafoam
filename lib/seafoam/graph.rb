# frozen_string_literal: true

require "set"

module Seafoam
  # A graph, with properties, nodes, and edges. We don't encapsulate the graph
  # too much - be careful.
  class Graph
    attr_reader :props, :nodes, :edges, :blocks, :new_id

    def initialize(props = nil)
      @props = props || {}
      @nodes = {}
      @edges = []
      @blocks = []
      @new_id = 0
    end

    # Create a node.
    def create_node(id, props = nil)
      props ||= {}
      node = Node.new(id, props)
      @nodes[id] = node
      @new_id = id + 1
      node
    end

    # Create an edge between two nodes.
    def create_edge(from, to, props = nil)
      props ||= {}
      edge = Edge.new(from, to, props)
      @edges.push(edge)
      from.outputs.push(edge)
      to.inputs.push(edge)
      edge
    end

    # Add a new basic block with given id and node id list.
    def create_block(id, node_ids)
      nodes = node_ids.select { |n| @nodes.key?(n) }.map { |n| @nodes[n] }
      block = Block.new(id, nodes)
      @blocks.push(block)
      block
    end

    def remove_edge(edge)
      edge.from.outputs.delete(edge)
      edge.to.inputs.delete(edge)
      edges.delete(edge)
    end
  end

  # A node, with properties, input edges, and output edges.
  class Node
    attr_reader :id, :inputs, :outputs, :props

    def initialize(id, props = nil)
      props ||= {}
      @id = id
      @inputs = []
      @outputs = []
      @props = props
    end

    def node_class
      @props.dig(:node_class, :node_class) || ""
    end

    # All edges - input and output.
    def edges
      inputs + outputs
    end

    # All adjacent nodes - from input and output edges.
    def adjacent
      (inputs.map(&:from) + outputs.map(&:to)).uniq
    end

    # id (label)
    def id_and_label
      if props[:label]
        "#{id} (#{props[:label]})"
      else
        id.to_s
      end
    end

    # Inspect.
    def inspect
      "<Node #{id} #{node_class}>"
    end

    def visit(&block)
      block.call(self)
    end

    def visit_outputs(search_strategy, &block)
      if search_strategy == :bfs
        BFS.new(self).search(&block)
      else
        raise "Unknown search strategy: #{search_strategy}"
      end
    end
  end

  # A directed edge, with a node it's from and a node it's going to, and
  # properties.
  class Edge
    attr_reader :from, :to, :props

    def initialize(from, to, props = nil)
      props ||= {}
      @from = from
      @to = to
      @props = props
    end

    # Both nodes - from and to.
    def nodes
      [@from, @to]
    end

    # Inspect.
    def inspect
      "<Edge #{from.id} -> #{to.id}>"
    end
  end

  # A control-flow basic block
  class Block
    attr_reader :id, :nodes

    def initialize(id, nodes)
      @id = id
      @nodes = nodes
    end

    # Inspect.
    def inspect
      "<Block #{id}>"
    end
  end
end
