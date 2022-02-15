require 'stringio'

require 'seafoam'

require 'rspec'

require_relative 'spec_helpers'

describe Seafoam::MarkdownWriter do
  describe '#write_graph' do
    before :all do
      file = File.expand_path('../../examples/graalvm-ce-java11-21.2.0/fib-java.bgv.gz', __dir__)
      parser = Seafoam::BGV::BGVParser.new(file)
      parser.read_file_header
      parser.read_graph_preheader
      parser.read_graph_header
      @fib_java_graph = parser.read_graph
    end

    before :each do
      @stream = StringIO.new
      @writer = Seafoam::MarkdownWriter.new(@stream)
    end

    it 'writes the header' do
      @writer.write_graph @fib_java_graph
      expect(@stream.string).to start_with '```mermaid'
    end

    it 'writes all graphs' do
      Seafoam::SpecHelpers::SAMPLE_BGV.each do |file|
        parser = Seafoam::BGV::BGVParser.new(file)
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
end
