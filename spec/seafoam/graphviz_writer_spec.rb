require 'stringio'

require 'seafoam'

require 'rspec'

describe Seafoam::GraphvizWriter do
  describe 'with a graph' do
    before :all do
      file = File.expand_path('../../examples/fib-java.bgv', __dir__)
      File.open(file) do |stream|
        parser = Seafoam::BGVParser.new(stream)
        parser.read_file_header
        parser.read_graph_preheader
        parser.read_graph_header
        @graph = parser.read_graph
      end
    end

    before :each do
      @stream = StringIO.new
      @writer = Seafoam::GraphvizWriter.new(@stream)
    end

    describe '#write_graph' do
      it 'writes the header' do
        @writer.write_graph @graph
        expect(@stream.string).to start_with 'digraph G {'
      end
    end
  end

  describe '#quote' do
    it 'adds quotes' do
      writer = Seafoam::GraphvizWriter.new(nil)
      expect(writer.send(:quote, 'foo')).to eq '"foo"'
    end

    it 'escapes an existing quote' do
      writer = Seafoam::GraphvizWriter.new(nil)
      expect(writer.send(:quote, 'foo"bar')).to eq '"foo\"bar"'
    end

    it 'escapes an existing escape' do
      writer = Seafoam::GraphvizWriter.new(nil)
      expect(writer.send(:quote, 'foo\bar')).to eq '"foo\\bar"'
    end
  end
end
