require 'seafoam'

require 'rspec'

require_relative '../spec_helpers'

describe Seafoam::CFG::Disassembler do
  it 'can successfully start Capstone Disassembler' do
    Seafoam::CFG::Disassembler.new
  end

  it 'can start Capstone Disassembler disassemble an nmethod' do
    @example_cfg = File.expand_path('../../../examples/java/exampleIf.cfg', __dir__)
    parser = Seafoam::CFG::CFGParser.new(@example_cfg)
    parser.skip_over_cfg 'After code installation'
    @nmethod = parser.read_nmethod
    disassembler = Seafoam::CFG::Disassembler.new
    disassembler.disassemble(@nmethod, 0)
  end
end
