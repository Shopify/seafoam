# frozen_string_literal: true

module Seafoam
  module Graal
    # Routines for understanding source positions in Graal.
    module Source
      class << self
        def walk(source_position, &block)
          results = []

          caller = source_position
          while caller
            method = caller[:method]
            results.push(block.call(method))
            caller = caller[:caller]
          end

          results
        end
      end
    end
  end
end
