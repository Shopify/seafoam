# frozen_string_literal: true

require "set"

module Seafoam
  class BFS
    attr_reader :root

    def initialize(root)
      @root = root
    end

    def search(&block)
      queue = root.outputs.collect(&:to)
      visited = Set.new

      until queue.empty?
        entry = queue.shift
        visited << entry

        result = entry.visit(&block)

        if result
          return result
        else
          entry.outputs.collect(&:to).each do |child|
            queue << child unless visited.include?(child)
          end
        end
      end
    end
  end
end
