require 'seafoam'

require 'rspec'

describe Seafoam::Spotlight do
  before :each do
    file = File.expand_path('../../examples/fib-java.bgv', __dir__)
    parser = Seafoam::BGVParser.new(File.new(file))
    parser.read_file_header
    parser.skip_document_props
    parser.read_graph_preheader
    parser.read_graph_header
    @graph = parser.read_graph
  end

  it 'marks individual nodes as lit' do
    spotlight = Seafoam::Spotlight.new(@graph)
    spotlight.light @graph.nodes[13]
    expect(@graph.nodes[13].props[:spotlight]).to eq 'lit'
  end

  it 'marks surrounding nodes as shaded' do
    spotlight = Seafoam::Spotlight.new(@graph)
    spotlight.light @graph.nodes[13]
    expect(@graph.nodes.values
      .select { |n| n.props[:spotlight] == 'shaded' }
      .map(&:id).sort).to eq [6, 12, 14, 18, 19, 20]
  end

  it 'marks other nodes as hidden' do
    spotlight = Seafoam::Spotlight.new(@graph)
    spotlight.light @graph.nodes[13]
    spotlight.shade
    expect(@graph.nodes.values
      .select { |n| n.props[:hidden] }
      .map(&:id).sort).to eq [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 15, 16, 17, 21]
  end
end
