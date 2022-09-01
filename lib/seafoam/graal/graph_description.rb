# frozen_string_literal: true

module Seafoam
  module Graal
    # Provides a high level description of a Graal graph's features.
    class GraphDescription
      ATTRIBUTES = [:branches, :calls, :deopts, :linear, :loops]

      ATTRIBUTES.each { |attr| attr_accessor(attr) unless attr == :linear }
      attr_reader :node_counts

      def initialize
        @branches = false
        @calls = false
        @deopts = false
        @loops = false
        @node_counts = Hash.new(0)
      end

      def linear
        !branches && !loops
      end

      def sorted_node_counts
        @node_counts.to_a.sort_by { |node_class, count| [-count, node_class] }.to_h
      end
    end
  end
end
