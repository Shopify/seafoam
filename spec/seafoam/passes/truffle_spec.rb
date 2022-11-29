# frozen_string_literal: true

require "seafoam"

require "rspec"

require_relative "../spec_helpers"

describe Seafoam::Passes::TrufflePass do
  it "does not apply to Java graphs" do
    expect(Seafoam::Passes::TrufflePass.applies?(Seafoam::SpecHelpers.example_graph("fib-java", 0))).to(be(false))
  end

  it "does not apply to Truffle trees" do
    expect(Seafoam::Passes::TrufflePass.applies?(Seafoam::SpecHelpers.example_graph("fib-js", 0))).to(be(false))
  end

  it "applies to Truffle graphs" do
    expect(Seafoam::Passes::TrufflePass.applies?(Seafoam::SpecHelpers.example_graph("fib-js", 2))).to(be(true))
  end

  describe "when run" do
    describe "with :simplify_alloc" do
      before :all do
        @graph = Seafoam::SpecHelpers.example_graph(
          File.expand_path("../../../examples/ruby/example_object_allocation.bgv", __dir__), 4
        )
        pass = Seafoam::Passes::TrufflePass.new(simplify_alloc: true, hide_null_fields: true)
        pass.apply(@graph)
      end

      it "hides all simple constant inputs to allocation nodes" do
        @graph.nodes.each_value do |node|
          next unless node.node_class == "org.graalvm.compiler.nodes.virtual.CommitAllocationNode"

          node.inputs.each do |input|
            next unless input.from.node_class == "org.graalvm.compiler.nodes.ConstantNode"

            if ["Object[null]", "0"].include?(input.from.props["rawvalue"])
              expect(input.from.props[:hidden]).to(be_truthy)
            end
          end
        end
      end
    end

    describe "with :simplify_truffle_args" do
      before :each do
        @filename = File.expand_path("../../../examples/ruby/example_if.bgv", __dir__)
        @phase_index = 4
        @graph = Seafoam::SpecHelpers.example_graph(@filename, @phase_index)
      end

      it "substitutes TruffleArgument nodes for LoadIndexed nodes" do
        before_load_indexed_nodes = @graph.nodes.values.select do |n|
          n.node_class == "org.graalvm.compiler.nodes.java.LoadIndexedNode"
        end.map(&:dup)
        before_truffle_argument_nodes = @graph.nodes.values.select do |n|
          n.props[:synthetic_class] == "TruffleArgument"
        end

        # Verify initial graph state.
        expect(before_load_indexed_nodes).not_to(be_empty)
        expect(before_truffle_argument_nodes).to(be_empty)

        # Run the Truffle argument simplification pass.
        graph = Seafoam::SpecHelpers.example_graph(@filename, @phase_index)
        pass = Seafoam::Passes::TrufflePass.new(simplify_truffle_args: true, hide_null_fields: true)
        pass.apply(graph)

        # Verify graph state after the pass has run.
        after_load_indexed_nodes = graph.nodes.values.select do |n|
          n.node_class == "org.graalvm.compiler.nodes.java.LoadIndexedNode"
        end
        after_truffle_argument_nodes = graph.nodes.values.select { |n| n.props[:synthetic_class] == "TruffleArgument" }

        # Verify state after the pass has run. This test only makes sense if the TruffleArgument node list is non-empty.
        expect(after_load_indexed_nodes.size).to(eq(before_load_indexed_nodes.size))
        expect(after_truffle_argument_nodes).not_to(be_empty)

        after_truffle_argument_nodes.each_with_index do |arg_node, index|
          # The "next" edges are never connected to the TruffleArgument node.
          rewritten_edges = before_load_indexed_nodes[index].outputs.select { |edge| edge.props[:name] != "next" }

          # The original LoadIndexed nodes should have no outgoing edges.
          expect(after_load_indexed_nodes[index].outputs).to(be_empty)

          # The new TruffleArgument nodes should have no incoming edges.
          expect(arg_node.inputs).to(be_empty)

          # The new TruffleArgument nodes should have edges pointing to the same edges the original LoadIndexed nodes
          # did, minus the "next" nodes.
          expect(arg_node.outputs.map(&:to).map(&:id)).to(eq(rewritten_edges.map(&:to).map(&:id)))
        end
      end
    end
  end
end
