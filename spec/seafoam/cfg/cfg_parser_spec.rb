require 'seafoam'

require 'rspec'

require_relative '../spec_helpers'

describe Seafoam::CFG::CFGParser do
  before :all do
    @example_cfg = File.expand_path('../../../examples/java/exampleIf.cfg', __dir__)
  end

  it 'can skip to an nmethod in a file' do
    parser = Seafoam::CFG::CFGParser.new(@example_cfg)
    parser.skip_over_cfg 'After code installation'
    parser.read_nmethod
  end

  it 'correctly parses information from an nmethod' do
    parser = Seafoam::CFG::CFGParser.new(@example_cfg)
    parser.skip_over_cfg 'After code installation'
    nmethod = parser.read_nmethod
    expect(nmethod[:code][:base]).to eq '112e35c20'.to_i(16)
    expect(nmethod[:comments].size).to eq 27
  end
end
