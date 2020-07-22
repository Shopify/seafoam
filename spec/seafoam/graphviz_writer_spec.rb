require 'stringio'

require 'seafoam'

require 'rspec'

require_relative 'spec_helpers'

describe Seafoam::GraphvizWriter do
  describe '#write_graph' do
    before :all do
      file = File.expand_path('../../examples/fib-java.bgv', __dir__)
      parser = Seafoam::BGVParser.new(File.new(file))
      parser.read_file_header
      parser.read_graph_preheader
      parser.read_graph_header
      @fib_java_graph = parser.read_graph
    end

    before :each do
      @stream = StringIO.new
      @writer = Seafoam::GraphvizWriter.new(@stream)
    end

    it 'writes the header' do
      @writer.write_graph @fib_java_graph
      expect(@stream.string).to start_with 'digraph G {'
    end

    it 'writes all graphs' do
      Seafoam::SpecHelpers::SAMPLE_BGV.each do |file|
        parser = Seafoam::BGVParser.new(File.new(file))
        parser.read_file_header
        parser.skip_document_props
        parser.skip_document_props
        loop do
          index, = parser.read_graph_preheader
          break unless index

          parser.read_graph_header
          @writer.write_graph parser.read_graph
        end
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
