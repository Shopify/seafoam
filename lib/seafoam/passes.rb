module Seafoam
  # Passes are routines to read the graph and apply properties which tools,
  # such as the render command, can use to show more understandable output.
  module Passes
    # Apply all applicable passes to a graph.
    def self.apply(graph, options = {})
      passes.each do |pass|
        next unless pass.applies?(graph)

        # Record for information that the pass was applied this graph.
        passes_applied = graph.props[:passes_applied] ||= []
        passes_applied.push pass

        # Run the pass.
        instance = pass.new(options)
        instance.apply graph
      end
    end

    # Get a list of all passes in the system.
    def self.passes
      # Get all subclasses of Pass.
      passes = Pass::SUBCLASSES.dup

      # We want the FallbackPass to run last.
      passes.delete FallbackPass
      passes.push FallbackPass

      passes
    end
  end

  # The base class for all passes. You must subclass this to be recognized
  # as an pass.
  class Pass
    SUBCLASSES = []

    def initialize(options = {})
      @options = options
    end

    def applies?(_graph)
      raise NotImplementedError
    end

    def apply(_graph)
      raise NotImplementedError
    end

    def self.inherited(pass)
      SUBCLASSES.push pass
    end
  end
end
