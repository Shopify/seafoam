require 'seafoam'

require 'rspec'

describe Seafoam::Annotators::FallbackAnnotator do
  it 'always applies' do
    expect(Seafoam::Annotators::FallbackAnnotator.applies?(Seafoam::Graph.new)).to be true
  end

  it 'adds a label annotation when there is a label property' do
    graph = Seafoam::Graph.new
    node = graph.create_node(0, 'label' => 'foo')
    annotator = Seafoam::Annotators::FallbackAnnotator.new
    annotator.annotate graph
    expect(node.props[:label]).to eq 'foo'
  end

  it 'does not overwrite an existing label annotation' do
    graph = Seafoam::Graph.new
    node = graph.create_node(0, 'label' => 'foo', :label => 'bar')
    annotator = Seafoam::Annotators::FallbackAnnotator.new
    annotator.annotate graph
    expect(node.props[:label]).to eq 'bar'
  end

  it 'adds nothing when there is no label property' do
    graph = Seafoam::Graph.new
    node = graph.create_node(0, 'xlabel' => 'foo')
    annotator = Seafoam::Annotators::FallbackAnnotator.new
    annotator.annotate graph
    expect(node.props[:label]).to be nil
  end

  it 'sets node kind to other when there is no kind' do
    graph = Seafoam::Graph.new
    node = graph.create_node(0)
    annotator = Seafoam::Annotators::FallbackAnnotator.new
    annotator.annotate graph
    expect(node.props[:kind]).to eq 'other'
  end

  it 'does not overwrite an existing node kind annotations' do
    graph = Seafoam::Graph.new
    node = graph.create_node(0, :kind => 'control')
    annotator = Seafoam::Annotators::FallbackAnnotator.new
    annotator.annotate graph
    expect(node.props[:kind]).to eq 'control'
  end

  it 'sets edge kind to other when there is no kind' do
    graph = Seafoam::Graph.new
    nodeA = graph.create_node(0)
    nodeB = graph.create_node(1)
    edge = graph.create_edge(nodeA, nodeB)
    annotator = Seafoam::Annotators::FallbackAnnotator.new
    annotator.annotate graph
    expect(edge.props[:kind]).to eq 'other'
  end

  it 'does not overwrite an existing edge kind annotations' do
    graph = Seafoam::Graph.new
    nodeA = graph.create_node(0)
    nodeB = graph.create_node(1)
    edge = graph.create_edge(nodeA, nodeB, :kind => 'control')
    annotator = Seafoam::Annotators::FallbackAnnotator.new
    annotator.annotate graph
    expect(edge.props[:kind]).to eq 'control'
  end
end
