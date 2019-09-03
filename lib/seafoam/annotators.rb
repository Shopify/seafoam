module Seafoam
  # Annotators are routines to read the graph and apply properties which tools,
  # such as the render command, can use to show more understandable output.
  module Annotators
    # Apply all applicable annotators to a graph.
    def self.apply(graph, options = {})
      annotators.each do |annotator|
        next unless annotator.applies?(graph)

        # Record for information that the annotator annotated this graph.
        annotated_by = graph.props[:annotated_by] ||= []
        annotated_by.push annotator

        # Run the annotator.
        instance = annotator.new(options)
        instance.annotate graph
      end
    end

    # Get a list of all annotators in the system.
    def self.annotators
      # Get all subclasses of Annotator.
      annotators = ObjectSpace.each_object(Class).filter { |klass| klass < Annotator }

      # We want the FallbackAnnotator to run last.
      annotators.delete FallbackAnnotator
      annotators.push FallbackAnnotator

      annotators
    end
  end

  # The base class for all annotators. You must subclass this to be recognized
  # as an annotator.
  class Annotator
    def initialize(options = {})
      @options = options
    end

    def applies?(_graph)
      raise NotImplementedError
    end

    def annotate(_graph)
      raise NotImplementedError
    end
  end
end
