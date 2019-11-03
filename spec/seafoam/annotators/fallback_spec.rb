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
end
