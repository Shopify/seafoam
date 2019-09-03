require 'seafoam'

require 'rspec'

describe Seafoam::Annotators do
  describe '#annotate' do
    it 'asks annotators if they apply' do
      check_applied = false

      Class.new(Seafoam::Annotator) do
        singleton_class.define_method(:applies?) do |_graph|
          check_applied = true
          false
        end
      end

      Seafoam::Annotators.apply(Seafoam::Graph.new)
      expect(check_applied).to be true
    end

    it 'runs annotators that apply' do
      check_annotated = false

      Class.new(Seafoam::Annotator) do
        singleton_class.define_method(:applies?) do |_graph|
          true
        end

        define_method(:annotate) do |_graph|
          check_annotated = true
        end
      end

      Seafoam::Annotators.apply(Seafoam::Graph.new)
      expect(check_annotated).to be true
    end
  end

  describe '#annotators' do
    it 'returns the standard annotators' do
      annotators = Seafoam::Annotators.annotators
      expect(annotators).to include Seafoam::Annotators::FallbackAnnotator
      expect(annotators).to include Seafoam::Annotators::GraalAnnotator
    end

    it 'returns custom annotators' do
      custom_annotator = Class.new(Seafoam::Annotator) do
        def self.applies?(_graph)
          false
        end
      end
      annotators = Seafoam::Annotators.annotators
      expect(annotators).to include custom_annotator
    end

    it 'returns the FallbackAnnotator annotator last' do
      annotators = Seafoam::Annotators.annotators
      expect(annotators.last).to eq Seafoam::Annotators::FallbackAnnotator
    end
  end
end
