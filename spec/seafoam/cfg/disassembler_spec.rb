require 'seafoam'

require 'rspec'

require_relative '../spec_helpers'

describe Seafoam::CFG::Disassembler do
  it 'can successfully start Capstone Disassembler' do
    Seafoam::CFG::Disassembler.new($stdout)
  end

  it 'can start Capstone Disassembler disassemble an nmethod with and without comments' do
    @example_cfg = File.expand_path('../../../examples/java/exampleIf.cfg', __dir__)
    @file = File.open('tempfile_disassembler_spec.txt', 'w')
    parser = Seafoam::CFG::CFGParser.new(@file, @example_cfg)
    parser.skip_over_cfg 'After code installation'
    @nmethod = parser.read_nmethod

    disassembler = Seafoam::CFG::Disassembler.new(@file)
    disassembler.disassemble(@nmethod, 0)
    @file.close

    expect(`wc -l 'tempfile_disassembler_spec.txt'`.to_i).to eq 52

    @file = File.open('tempfile_disassembler_spec.txt', 'w')
    disassembler = Seafoam::CFG::Disassembler.new(@file)
    disassembler.disassemble(@nmethod, 2)
    @file.close

    expect(`wc -l 'tempfile_disassembler_spec.txt'`.to_i).to eq 52

    File.delete(@file)
  end
end
