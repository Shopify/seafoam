# frozen_string_literal: true

module Seafoam
  # Write graphs in the Isabelle file format.
  class IsabelleWriter
    def initialize(out)
      @out = out
    end

    def write(index, name, graph)
      # definition eg_short_cut_or1 :: IRGraph where
      #   "eg_short_cut_or1 =
      #     (add_node 14 ReturnNode [13] []
      #     (add_node 13 PhiNode [10, 11, 12] []
      #     (add_node 12 (ConstantNode 0) [] []
      #     (add_node 11 (ConstantNode 42) [] []
      #     (add_node 10 MergeNode [7, 9] [14]
      #     (add_node 9 EndNode [] []
      #     (add_node 8 BeginNode [] [9]
      #     (add_node 7 EndNode [] []
      #     (add_node 6 BeginNode [] [7]
      #     (add_node 5 IfNode [3] [6, 8]
      #     (add_node 3 (ShortCircuitOrNode False False) [1, 2] []
      #     (add_node 2 (ParameterNode 1) [] []
      #     (add_node 1 (ParameterNode 0) [] []
      #     (add_node 0 StartNode [] [5]
      #     empty_graph))))))))))))))"

      @out.puts "graph#{index} = # #{name}"

      graph.nodes.each_value do |node|
        node_class = node.props[:node_class][:node_class]
        desc = case node_class
        when "org.graalvm.compiler.nodes.ConstantNode"
          "(ConstantNode #{node.props["rawvalue"]})"
        when "org.graalvm.compiler.nodes.ParameterNode"
          "(ParameterNode #{node.props["index"]})"
        else
          node_class.split(".").last
        end
        inputs = node.inputs.map(&:from).map(&:id)
        outputs = node.outputs.map(&:to).map(&:id)
        @out.puts " (add_node #{node.id} #{desc} #{inputs.inspect} #{outputs.inspect}"
      end
      @out.puts " empty_graph" + (")" * graph.nodes.size)
    end
  end
end
