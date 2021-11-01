module Seafoam
  module Decompiler
    class Pseudo
      def initialize(out)
        @writer = Writer.new(out, 2)
      end

      def decompile(node)
        case node
        when AST::FunctionNode
          @writer.line 'function(args)'
          @writer.indent do
            decompile node.body
          end
          @writer.line 'end'
        when AST::SequenceNode
          node.sequence.each do |n|
            decompile n
          end
        when AST::OperationNode
          @writer.line do |line|
            line.print "t#{node.output} = " if node.output
            line.print node.operation.props[:label]
            line.print "(#{node.inputs.map { |i| "t#{i}" }.join(', ')})" if node.inputs.any?
          end
        when AST::MoveNode
          @writer.line "t#{node.to} = t#{node.from}"
        when AST::BasicBlockCallNode
          @writer.label "b#{node.label}:"
          decompile node.body
          @writer.line do |line|
            line.print "t#{node.output} = " if node.output
            line.print node.call.props[:label]
            #line.print "(#{node.inputs.map { |i| "t#{i}" }.join(', ')})" if node.inputs.any?
            line.print " catch goto b#{node.exceptional_target}"
          end
          @writer.line "goto b#{node.normal_target}"
        when AST::BasicBlockFallThroughNode
          @writer.label "b#{node.label}:"
          decompile node.body
        when AST::BasicBlockGotoNode
          @writer.label "b#{node.label}:"
          decompile node.body
          @writer.line "goto b#{node.target}"
        when AST::BasicBlockGotoIfNode
          @writer.label "b#{node.label}:"
          decompile node.body
          @writer.line "if t#{node.condition} goto b#{node.true_target} else goto b#{node.false_target}"
        when AST::BasicBlockReturnNode
          @writer.label "b#{node.label}:"
          decompile node.body
          if node.value
            @writer.line "return t#{node.value}"
          else
            @writer.line 'return'
          end
        when AST::BasicBlockThrowNode
          @writer.label "b#{node.label}:"
          decompile node.body
          @writer.line "throw t#{node.value}"
        else
          raise node.class.name
        end
      end
    end
  end
end
