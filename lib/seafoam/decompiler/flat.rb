module Seafoam
  module Decompiler
    class FlatDecompiler
      def to_ast(schedule)
        ast_blocks = []

        schedule.each do |block|
          body_nodes = block.nodes.take(block.nodes.size - 1)
          flow_node = block.nodes.last

          body_ast_nodes = []
          body_nodes.each do |node|
            case node.props.dig(:node_class, :node_class)
            when 'org.graalvm.compiler.nodes.StartNode'
            when 'org.graalvm.compiler.nodes.KillingBeginNode'
            when 'org.graalvm.compiler.nodes.BeginNode'
            when 'org.graalvm.compiler.nodes.EndNode'
            when 'org.graalvm.compiler.nodes.LoopExitNode'
            when 'org.graalvm.compiler.nodes.LoopBeginNode'
            when 'org.graalvm.compiler.nodes.ValuePhiNode'
            when 'org.graalvm.compiler.nodes.MergeNode'
            else
              inputs = node.inputs.select { |i| !i.props[:hidden] && i.props[:kind] != 'control' }
              outputs = node.outputs.select { |i| !i.props[:hidden] && i.props[:kind] != 'control' }
              body_ast_nodes.push AST::OperationNode.new(inputs.map { |i| i.from.id }, node, node.id)

              outputs.each do |output|
                if output.to.props.dig(:node_class, :node_class) == 'org.graalvm.compiler.nodes.ValuePhiNode'
                  body_ast_nodes.push AST::MoveNode.new(node.id, output.to.id)
                end
              end
            end
          end
          body = AST::SequenceNode.new(body_ast_nodes)

          flow_node_class = flow_node.props.dig(:node_class, :node_class)
          case flow_node.props.dig(:node_class, :node_class)
          when 'org.graalvm.compiler.nodes.EndNode'
            next_node = flow_node.outputs.find { |o| o.props[:name] == 'ends' }&.to
            if next_node
              next_block = schedule.find { |b| b.nodes.include?(next_node) }
              block_node = AST::BasicBlockGotoNode.new(block.id, body, next_block.id)
            else
              block_node = AST::BasicBlockFallThroughNode.new(block.id, body)
            end
          when 'org.graalvm.compiler.nodes.IfNode'
            condition_node = flow_node.inputs.find { |o| o.props[:name] == 'condition' }.from
            true_node = flow_node.outputs.find { |o| o.props[:name] == 'trueSuccessor' }.to
            false_node = flow_node.outputs.find { |o| o.props[:name] == 'falseSuccessor' }.to
            true_block = schedule.find { |b| b.nodes.include?(true_node) }
            false_block = schedule.find { |b| b.nodes.include?(false_node) }
            block_node = AST::BasicBlockGotoIfNode.new(block.id, body, condition_node.id, true_block.id, false_block.id)
          when 'org.graalvm.compiler.nodes.LoopEndNode'
            begin_node = flow_node.inputs.find { |i| i.props[:name] == 'loopBegin' }.from
            begin_block = schedule.find { |b| b.nodes.include?(begin_node) }
            block_node = AST::BasicBlockGotoNode.new(block.id, body, begin_block.id)
          when 'org.graalvm.compiler.nodes.ReturnNode'
            result_node = flow_node.inputs.find { |o| o.props[:name] == 'result' }&.from
            block_node = AST::BasicBlockReturnNode.new(block.id, body, result_node&.id)
          when 'org.graalvm.compiler.nodes.UnwindNode'
            result_node = flow_node.inputs.find { |o| o.props[:name] == 'exception' }.from
            block_node = AST::BasicBlockThrowNode.new(block.id, body, result_node.id)
          when 'org.graalvm.compiler.nodes.InvokeWithExceptionNode'
            normal_node = flow_node.outputs.find { |o| o.props[:name] == 'next' }.to
            exceptional_node = flow_node.outputs.find { |o| o.props[:name] == 'exceptionEdge' }.to
            normal_block = schedule.find { |b| b.nodes.include?(normal_node) }
            exceptional_block = schedule.find { |b| b.nodes.include?(exceptional_node) }
            block_node = AST::BasicBlockCallNode.new(block.id, body, flow_node, flow_node.id, normal_block.id, exceptional_block.id)
          else
            raise "unknown flow node #{flow_node.inspect}"
          end

          ast_blocks.push block_node
        end

        AST::FunctionNode.new(AST::SequenceNode.new(ast_blocks))
      end
    end
  end
end
