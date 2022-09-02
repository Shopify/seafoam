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
    before :all do
      @graph = Seafoam::SpecHelpers.example_graph(
        File.expand_path("../../../examples/ruby/example_object_allocation.bgv", __dir__), 4
      )
      pass = Seafoam::Passes::TrufflePass.new(simplify_alloc: true, hide_null_fields: true)
      pass.apply(@graph)
    end

    describe "with :simplify_alloc" do
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
  end
end
