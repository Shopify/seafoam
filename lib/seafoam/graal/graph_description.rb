module Seafoam
  module Graal
    # Provides a high level description of a Graal graph's features.
    class GraphDescription
      ATTRIBUTES = %i[branches calls deopts linear loops]

      ATTRIBUTES.each { |attr| attr_accessor(attr) unless attr == :linear }

      def initialize
        @branches = false
        @calls = false
        @deopts = false
        @loops = false
      end

      def linear
        !branches && !loops
      end
    end
  end
end
