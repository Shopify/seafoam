module Seafoam
  # Decompiles graphs into pseudo-code.
  class Decompiler
    def initialize(stream)
      @stream = stream
      @indent = 0
    end

    def decompile(graph)
      puts 'def foo(*args)'
      indented do
        start = graph.nodes[0]
        next_node = decompile_block(start)
        raise next_node.id_and_label if next_node
      end
      puts 'end'
    end

    def decompile_block(node)
      pointer = node
      while pointer
        if pointer.outputs.any? { |output| output.props[:kind] == 'loop' }
          pointer = decompile_loop(pointer)
        else
          control_out = pointer.outputs.select { |output| output.props[:kind] == 'control' }
          if control_out.size == 2
            pointer = decompile_branch(pointer)
          else
            decompile_scheduled_nodes pointer
            decompile_node pointer
            if control_out.size == 1
              # Linear control node.
              pointer = control_out.first.to
            elsif control_out.empty?
              # Exit point.
              pointer = nil
            else
              raise
            end
          end
        end
      end
    end

    def decompile_scheduled_nodes(node)
      schedule = []
      worklist = [node]
      until worklist.empty?
        x = worklist.shift
        schedule.push x
        worklist.push(*x.inputs.select { |input| input.props[:kind] == 'schedule' }.map(&:from))
      end
      schedule.delete node
      schedule.reverse.each do |scheduled|
        decompile_node scheduled
      end
    end

    def decompile_node(node)
      builder = []

      produces_value = node.outputs.any? { |output| output.props[:kind] != 'control' }

      if produces_value
        builder.push "v#{node.id} = "
      end

      builder.push node.props[:label]

      builder.push '('

      args = node.inputs.filter { |input| input.props[:kind] != 'control' && input.props[:kind] != 'schedule' }
      builder.push args.map { |input| node_input_name(input.from) }.join(', ')

      builder.push ')'

      unless produces_value
        builder.push " # node #{node.id}"
      end

      puts builder.join('')
    end

    def node_input_name(node)
      if node.props[:inlined]
        node.props[:label]
      else
        "v#{node.id}"
      end
    end

    def decompile_loop(node)
      puts 'loop do'
      block = node.outputs.select { |output| output.props[:kind] == 'control' }.first.to
      next_node = nil
      indented do
        next_node = decompile_block(block)
      end
      puts 'end'
      next_node
    end

    def decompile_branch(branch)
      decompile_scheduled_nodes branch
      condition = branch.inputs.find { |input| input.props[:name] == 'condition' }.from
      puts "if #{node_input_name(condition)}"
      next_true, next_false = nil
      indented do
        true_branch = branch.outputs.find { |output| output.props[:name] == 'trueSuccessor' }.to
        raise unless true_branch

        next_true = decompile_block(true_branch)
      end
      puts 'else'
      indented do
        false_branch = branch.outputs.find { |output| output.props[:name] == 'falseSuccessor' }.to
        raise unless false_branch

        next_false = decompile_block(false_branch)
      end
      puts 'end'
      # Either next_true and next_false need to be the same thing, or one of
      # them needs to be nil.
      if next_true == next_false
        next_true
      elsif next_false.nil?
        next_true
      elsif next_true.nil?
        next_false
      else
        raise
      end
    end

    private

    def indented
      @indent += 1
      begin
        yield
      ensure
        @indent -= 1
      end
    end

    def puts(string)
      @stream.print '  ' * @indent
      @stream.puts string
    end
  end
end
