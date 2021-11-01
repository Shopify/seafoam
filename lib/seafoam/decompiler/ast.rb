module Seafoam
  module Decompiler
    module AST
      FunctionNode = Struct.new(:body)
      SequenceNode = Struct.new(:sequence)
      OperationNode = Struct.new(:inputs, :operation, :output)
      MoveNode = Struct.new(:from, :to)
      BasicBlockCallNode = Struct.new(:label, :body, :call, :output, :normal_target, :exceptional_target)
      BasicBlockFallThroughNode = Struct.new(:label, :body)
      BasicBlockGotoNode = Struct.new(:label, :body, :target)
      BasicBlockGotoIfNode = Struct.new(:label, :body, :condition, :true_target, :false_target)
      BasicBlockReturnNode = Struct.new(:label, :body, :value)
      BasicBlockThrowNode = Struct.new(:label, :body, :value)
    end
  end
end
