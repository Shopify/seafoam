require 'seafoam'

require 'rspec'

require_relative '../spec_helpers'

describe Seafoam::Passes::GraalPass do
  it 'applies to Graal graphs' do
    expect(Seafoam::Passes::GraalPass.applies?(Seafoam::SpecHelpers.example_graph('fib-java', 0))).to be true
  end

  it 'does not apply to Truffle trees' do
    expect(Seafoam::Passes::GraalPass.applies?(Seafoam::SpecHelpers.example_graph('fib-js', 0))).to be false
  end

  it 'applies to Truffle graphs' do
    expect(Seafoam::Passes::GraalPass.applies?(Seafoam::SpecHelpers.example_graph('fib-js', 2))).to be true
  end

  describe 'when run' do
    describe 'without options' do
      before :all do
        @graph = Seafoam::SpecHelpers.example_graph('fib-ruby', 2)
        pass = Seafoam::Passes::GraalPass.new({})
        pass.apply @graph
      end

      it 'annotates all nodes with a kind' do
        expect(@graph.nodes.values.any? { |n| n.props[:kind].nil? }).to be_falsey
      end

      it 'annotates all nodes with a label' do
        expect(@graph.nodes.values.any? { |n| n.props[:label].nil? }).to be_falsey
      end

      it 'annotates all edges with a kind' do
        expect(@graph.edges.any? { |e| e.props[:kind].nil? }).to be_falsey
      end

      it 'annotates not negated GuardNodes with "Guard, else ..."' do
        expect(@graph.nodes[2497].props['negated']).to be false
        expect(@graph.nodes[2497].props[:label]).to start_with 'Guard, else'
      end

      it 'annotates negated GuardNodes with "Guard not, else ..."' do
        expect(@graph.nodes[1192].props['negated']).to be true
        expect(@graph.nodes[1192].props[:label]).to start_with 'Guard not, else'
      end
    end

    describe 'with :hide_frame_state' do
      before :all do
        @graph = Seafoam::SpecHelpers.example_graph('fib-ruby', 2)
        pass = Seafoam::Passes::GraalPass.new(hide_frame_state: true)
        pass.apply @graph
      end

      it 'sets the hidden property on all frame state nodes' do
        frame_state_nodes = @graph.nodes.values.select do |n|
          Seafoam::Passes::GraalPass::FRAME_STATE_NODES.include?(n.props.dig(:node_class, :node_class))
        end
        expect(frame_state_nodes.all? { |n| n.props[:hidden] }).to be_truthy
      end
    end

    describe 'with :hide_floating' do
      before :all do
        @graph = Seafoam::SpecHelpers.example_graph('fib-ruby', 2)
        pass = Seafoam::Passes::GraalPass.new(hide_floating: true)
        pass.apply @graph
      end

      it 'sets the hidden property on all nodes without a control edge' do
        nodes_without_control_edge = @graph.nodes.values.select do |n|
          n.edges.none? { |e| e.props[:kind] == 'control' }
        end
        expect(nodes_without_control_edge.all? { |n| n.props[:hidden] }).to be_truthy
      end
    end

    describe 'with :reduce_edges' do
      before :all do
        @graph = Seafoam::SpecHelpers.example_graph('fib-ruby', 2)
        pass = Seafoam::Passes::GraalPass.new(reduce_edges: true)
        pass.apply @graph
      end

      it 'inlines all constant nodes' do
        constant_nodes = @graph.nodes.values.select do |n|
          Seafoam::Passes::GraalPass::SIMPLE_INPUTS.include?(n.props.dig(:node_class, :node_class))
        end
        expect(constant_nodes.all? { |n| n.props[:inlined] }).to be_truthy
      end
    end
  end
end
