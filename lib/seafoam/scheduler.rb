require 'set'

module Seafoam
  # The scheduler creates basic blocks, a linear order within each basic
  # block, and a linear order of basic blocks.
  class Scheduler
    attr_reader :blocks

    def initialize(graph)
      @graph = graph
      @blocks = []
    end

    def schedule
      schedule_from_input
      schedule_globally
      schedule_locally
      schedule_blocks
      validate
    end

    private

    # The node can contain information about what nodes are in basic blocks -
    # population that information to start the schedule.
    def schedule_from_input
      @graph.blocks.each do |input_block|
        block = BasicBlock.new(input_block.id)
        block.nodes.push(*input_block.nodes)
        blocks.push block
      end

      @graph.nodes.each_value do |node|
        unless blocks.flat_map(&:nodes).include?(node)
          blocks.first.nodes.push node
        end
      end
    end

    # Put every node into a basic block.
    def schedule_globally
      # For now we just assume this has been done by Graal.
      validate_globally
    end

    # Within every basic block, give a single linear order of basic blocks.
    def schedule_locally
      blocks.each do |block|
        to_schedule = block.nodes.reject { |node| node.props[:hidden] }
        within_block = Set.new(to_schedule)
        block.nodes.clear
        scheduled = Set.new
        until to_schedule.empty?
          next_index = to_schedule.find_index do |node|
            predecessors(node).all? { |pred| !within_block.include?(pred) || scheduled.include?(pred) }
          end
          raise "can't find a ready node out of #{to_schedule.map(&:id).join(', ')}" unless next_index

          next_node = to_schedule.delete_at(next_index)

          scheduled.add next_node
          block.nodes.push next_node
        end
      end
    end

    # Give a global linear order of basic blocks.
    def schedule_blocks
      # Leave as the default schedule order for now.
    end

    # Check that the schedule is valid.
    def validate
      validate_globally
      validate_locally
    end

    # Check all nodes are globally scheduled.
    def validate_globally
      scheduled_nodes = Set.new(blocks.flat_map(&:nodes).reject { |node| node.props[:hidden] })
      @graph.nodes.values.reject { |node| node.props[:hidden] }.each do |node|
        unless scheduled_nodes.include?(node)
          raise "node #{node.id} not within block"
        end
      end
    end

    # Within each block, check all inputs appear before users.
    def validate_locally
      blocks.each do |block|
        scheduled_within_block = Set.new
        block.nodes.reject { |node| node.props[:hidden] }.each do |node|
          predecessors(node).select.each do |pred|
            next unless block.nodes.include?(pred)
            unless scheduled_within_block.include?(pred)
              raise "node #{pred.id} used before locally scheduled"
            end
          end
          scheduled_within_block.add node
        end
      end
    end

    def predecessors(node)
      node.inputs.reject { |edge| edge.props[:reverse] || edge.props[:hidden] }.map(&:from) + node.outputs.select { |edge| edge.props[:reverse] && !edge.props[:hidden] }.map(&:to)
    end

    # A basic block contains nodes a linear sequence of nodes with one exit.
    class BasicBlock
      attr_reader :id
      attr_reader :nodes

      def initialize(id)
        @id = id
        @nodes = []
      end
    end
  end
end
