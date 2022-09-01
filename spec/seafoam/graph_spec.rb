# frozen_string_literal: true

require "seafoam"

require "rspec"

describe Seafoam::Graph do
  describe "#initialize" do
    it "set properties" do
      graph = Seafoam::Graph.new(a: 12)
      expect(graph.props[:a]).to(eq(12))
    end
  end

  describe "#create_node" do
    it "adds a node to the graph" do
      graph = Seafoam::Graph.new
      node = graph.create_node(14)
      expect(graph.nodes.values).to(include(node))
    end

    it "set properties" do
      graph = Seafoam::Graph.new
      node = graph.create_node(14, a: 12)
      expect(node.props[:a]).to(eq(12))
    end

    it "returns the node" do
      graph = Seafoam::Graph.new
      node = graph.create_node(14)
      expect(node.id).to(eq(14))
    end
  end

  describe "#create_edge" do
    it "adds an edge to the graph" do
      graph = Seafoam::Graph.new
      from = graph.create_node(14)
      to = graph.create_node(2)
      edge = graph.create_edge(from, to)
      expect(graph.edges).to(include(edge))
    end

    it "set properties" do
      graph = Seafoam::Graph.new
      from = graph.create_node(14)
      to = graph.create_node(2)
      edge = graph.create_edge(from, to, a: 12)
      expect(edge.props[:a]).to(eq(12))
    end

    it "returns the edge" do
      graph = Seafoam::Graph.new
      from = graph.create_node(14)
      to = graph.create_node(2)
      edge = graph.create_edge(from, to)
      expect(edge.from).to(eq(from))
      expect(edge.to).to(eq(to))
    end
  end
end

describe Seafoam::Node do
  describe "#inputs" do
    it "returns only input edges" do
      graph = Seafoam::Graph.new
      node_a = graph.create_node(1)
      node_b = graph.create_node(2)
      node_c = graph.create_node(3)
      node_d = graph.create_node(4)
      in_edge = graph.create_edge(node_a, node_b)
      out_edge = graph.create_edge(node_b, node_c)
      unrelated_edge = graph.create_edge(node_c, node_d)
      expect(node_b.inputs).to(include(in_edge))
      expect(node_b.inputs).to_not(include(out_edge))
      expect(node_b.inputs).to_not(include(unrelated_edge))
    end
  end

  describe "#outputs" do
    it "returns only output edges" do
      graph = Seafoam::Graph.new
      node_a = graph.create_node(1)
      node_b = graph.create_node(2)
      node_c = graph.create_node(3)
      node_d = graph.create_node(4)
      in_edge = graph.create_edge(node_a, node_b)
      out_edge = graph.create_edge(node_b, node_c)
      unrelated_edge = graph.create_edge(node_c, node_d)
      expect(node_b.outputs).to_not(include(in_edge))
      expect(node_b.outputs).to(include(out_edge))
      expect(node_b.outputs).to_not(include(unrelated_edge))
    end
  end

  describe "#edges" do
    it "returns both input and output edges" do
      graph = Seafoam::Graph.new
      node_a = graph.create_node(1)
      node_b = graph.create_node(2)
      node_c = graph.create_node(3)
      node_d = graph.create_node(4)
      in_edge = graph.create_edge(node_a, node_b)
      out_edge = graph.create_edge(node_b, node_c)
      unrelated_edge = graph.create_edge(node_c, node_d)
      expect(node_b.edges).to(include(in_edge))
      expect(node_b.edges).to(include(out_edge))
      expect(node_b.edges).to_not(include(unrelated_edge))
    end
  end

  describe "#adjacent" do
    it "returns nodes from both input and output edges" do
      graph = Seafoam::Graph.new
      node_a = graph.create_node(1)
      node_b = graph.create_node(2)
      node_c = graph.create_node(3)
      node_d = graph.create_node(4)
      graph.create_edge(node_a, node_b)
      graph.create_edge(node_b, node_c)
      graph.create_edge(node_c, node_d)
      expect(node_b.adjacent).to(include(node_a))
      expect(node_b.adjacent).to(include(node_c))
      expect(node_b.adjacent).to_not(include(node_d))
    end
  end

  describe "#id_and_label" do
    it "returns an id and label if there is one" do
      node = Seafoam::Node.new(14, label: "foo")
      expect(node.id_and_label).to(eq("14 (foo)"))
    end

    it "returns just an id if there is no label" do
      node = Seafoam::Node.new(14)
      expect(node.id_and_label).to(eq("14"))
    end
  end
end

describe Seafoam::Edge do
  describe "#from" do
    it "returns the from node" do
      graph = Seafoam::Graph.new
      node_a = graph.create_node(1)
      node_b = graph.create_node(2)
      edge = graph.create_edge(node_a, node_b)
      expect(edge.from).to(eq(node_a))
    end
  end

  describe "#to" do
    it "returns the to node" do
      graph = Seafoam::Graph.new
      node_a = graph.create_node(1)
      node_b = graph.create_node(2)
      edge = graph.create_edge(node_a, node_b)
      expect(edge.to).to(eq(node_b))
    end
  end

  describe "#nodes" do
    it "returns both the from and to node" do
      graph = Seafoam::Graph.new
      node_a = graph.create_node(1)
      node_b = graph.create_node(2)
      node_c = graph.create_node(3)
      edge = graph.create_edge(node_a, node_b)
      expect(edge.nodes).to(include(node_a))
      expect(edge.nodes).to(include(node_b))
      expect(edge.nodes).to_not(include(node_c))
    end
  end
end
