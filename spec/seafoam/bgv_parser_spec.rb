require 'seafoam'

require 'rspec'

require_relative 'spec_helpers'

describe Seafoam::BGVParser do
  before :all do
    @fib_java_bgv = File.expand_path('../../examples/fib-java.bgv', __dir__)
  end

  it 'can read full files' do
    Seafoam::SpecHelpers::SAMPLE_BGV.each do |file|
      parser = Seafoam::BGVParser.new(File.new(file))
      parser.read_file_header
      parser.skip_document_props
      loop do
        index, = parser.read_graph_preheader
        break unless index

        parser.read_graph_header
        parser.read_graph
      end
    end
  end

  it 'can skip full files' do
    Seafoam::SpecHelpers::SAMPLE_BGV.each do |file|
      parser = Seafoam::BGVParser.new(File.new(file))
      parser.read_file_header
      parser.skip_document_props
      loop do
        index, = parser.read_graph_preheader
        break unless index

        parser.skip_graph_header
        parser.skip_graph
      end
    end
  end

  it 'can alternate skipping and reading full files' do
    Seafoam::SpecHelpers::SAMPLE_BGV.each do |file|
      parser = Seafoam::BGVParser.new(File.new(file))
      parser.read_file_header
      parser.skip_document_props
      skip = false
      loop do
        index, = parser.read_graph_preheader
        break unless index

        if skip
          parser.skip_graph_header
          parser.skip_graph
        else
          parser.read_graph_header
          parser.read_graph
        end
        skip = !skip
      end
    end
  end

  describe '#read_file_header' do
    it 'produces a version' do
      parser = Seafoam::BGVParser.new(File.new(@fib_java_bgv))
      expect(parser.read_file_header).to eq [6, 1]
    end

    it 'raises an error for files which are not BGV' do
      parser = Seafoam::BGVParser.new(File.new(File.expand_path('bgv-fixtures/not.bgv', __dir__)))
      expect { parser.read_file_header }.to raise_error(EncodingError)
    end

    it 'raises an error for files which are an unsupported version of BGV' do
      parser = Seafoam::BGVParser.new(File.new(File.expand_path('bgv-fixtures/unsupported.bgv', __dir__)))
      expect { parser.read_file_header }.to raise_error(NotImplementedError)
    end

    it 'does not raise an error for an unsupported version of BGV if version_check is disabled' do
      parser = Seafoam::BGVParser.new(File.new(File.expand_path('bgv-fixtures/unsupported.bgv', __dir__)))
      expect(parser.read_file_header(version_check: false)).to eq [7, 2]
    end
  end

  describe '#read_graph_preheader' do
    it 'produces an index and id' do
      parser = Seafoam::BGVParser.new(File.new(@fib_java_bgv))
      parser.read_file_header
      parser.skip_document_props
      expect(parser.read_graph_preheader).to eq [0, 0]
    end

    it 'returns nil for end of file' do
      parser = Seafoam::BGVParser.new(File.new(@fib_java_bgv))
      parser.read_file_header
      parser.skip_document_props
      51.times do
        expect(parser.read_graph_preheader).to_not be_nil
        parser.skip_graph_header
        parser.skip_graph
      end
      expect(parser.read_graph_preheader).to be_nil
    end

    it 'returns unique indicies' do
      parser = Seafoam::BGVParser.new(File.new(@fib_java_bgv))
      parser.read_file_header
      parser.skip_document_props
      indicies = []
      5.times do
        index, = parser.read_graph_preheader
        expect(indicies).to_not include index
        indicies.push index
        parser.skip_graph_header
        parser.skip_graph
      end
    end
  end

  describe '#read_graph_header' do
    it 'produces an expected header' do
      parser = Seafoam::BGVParser.new(File.new(@fib_java_bgv))
      parser.read_file_header
      parser.skip_document_props
      parser.read_graph_preheader
      header = parser.read_graph_header
      expect(header[:props]['scope']).to eq 'main.Compiling.GraalCompiler.FrontEnd.PhaseSuite.GraphBuilderPhase'
    end
  end

  describe '#read_graph' do
    it 'produces an expected graph' do
      parser = Seafoam::BGVParser.new(File.new(@fib_java_bgv))
      parser.read_file_header
      parser.skip_document_props
      parser.read_graph_preheader
      parser.read_graph_header
      graph = parser.read_graph
      expect(graph.nodes.size).to eq 22
      expect(graph.edges.size).to eq 30
    end
  end
end
