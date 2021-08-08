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
      # We have a defined order for passes to run - these passes at the start.
      pre_passes = [
        GraalPass
      ]

      # The fallback pass runs last.
      post_passes = [
        FallbackPass
      ]

      # Any extra passes in the middle.
      extra_passes = Pass::SUBCLASSES.dup - pre_passes - post_passes

      pre_passes + extra_passes + post_passes
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
