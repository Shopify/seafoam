# frozen_string_literal: true

require "tsort"

module Seafoam
  module Passes
    # The Truffle pass applies if it looks like it was compiled by Truffle.
    class TrufflePass < Pass
      class << self
        def applies?(graph)
          graph.props.values.any? do |v|
            TRIGGERS.any? { |t| v.to_s.include?(t) }
          end
        end
      end

      def apply(graph)
        simplify_truffle_args(graph) if @options[:simplify_truffle_args]
        simplify_alloc(graph) if @options[:simplify_alloc]
        hide_reachability_fences(graph) if @options[:hide_reachability_fences]
      end

      private

      # Simplify a Truffle argument load into a single, inlined, node very much
      # like a Graal parameter node.
      def simplify_truffle_args(graph)
        graph.nodes.dup.each_value do |node|
          next unless node.node_class.end_with?(".compiler.nodes.java.LoadIndexedNode")

          index_node = node.inputs.find { |edge| edge.props[:name] == "index" }.from
          array_node = Graal::Pi.follow_pi_object(node.inputs.find { |edge| edge.props[:name] == "array" }.from)

          next unless index_node.node_class.end_with?(".compiler.nodes.ConstantNode")
          next unless array_node.node_class.end_with?(".compiler.nodes.ParameterNode")

          node.props[:truffle_arg_load] = true

          lang_formatter = Seafoam::Passes::TruffleTranslators.get_translator(node)
          index = lang_formatter.translate_argument_load(index_node.props["rawvalue"].to_i)

          arg_node = graph.create_node(
            graph.new_id,
            { synthetic: true, synthetic_class: "TruffleArgument", inlined: true, label: "T(#{index})", kind: "input" },
          )

          edges_to_remove = []

          node.outputs.each do |output|
            next if output.props[:name] == "next"

            graph.create_edge(arg_node, output.to, output.props.dup)
            edges_to_remove << output
          end

          edges_to_remove.each { |edge| graph.remove_edge(edge) }
        end

        graph.nodes.each_value.select { |node| node.props[:truffle_arg_load] }.each do |node|
          control_in = node.inputs.find { |edge| edge.props[:name] == "next" }
          control_out = node.outputs.find { |edge| edge.props[:name] == "next" }
          graph.create_edge(control_in.from, control_out.to, { name: "next" })
          graph.remove_edge(control_in)
          graph.remove_edge(control_out)
        end
      end

      # Hide nodes that are uninteresting inputs to an allocation node. These
      # are constants that are null or 0.
      def simplify_alloc(graph)
        commit_allocation_nodes = graph.nodes.each_value.select do |node|
          node.node_class.end_with?(".compiler.nodes.virtual.CommitAllocationNode")
        end

        commit_allocation_nodes.each do |commit_allocation_node|
          control_flow_pred = commit_allocation_node.inputs.first
          control_flow_next = commit_allocation_node.outputs.first

          objects = []
          virtual_to_object = {}

          # First step to fill virtual_to_object and avoid ordering issues
          commit_allocation_node.props.each_pair do |key, value|
            m = /^object\((\d+)\)$/.match(key)
            next unless m

            virtual_id = m[1].to_i

            m = /^([[:alnum:]$]+(?:\[\])?)\[([0-9,]+)\]$/.match(value)

            unless m
              raise "Unexpected value in allocation node: '#{value}'"
            end

            class_name, values = m.captures
            values = values.split(",").map(&:to_i)
            virtual_node = graph.nodes[virtual_id]
            if virtual_node.node_class.end_with?(".compiler.nodes.virtual.VirtualArrayNode")
              label = "New #{class_name[0...-1]}#{virtual_node.props["length"]}]"
              fields = values.size.times.to_a
            else
              label = "New #{class_name}"
              fields = virtual_node.props["fields"].map { |field| field[:name] }
            end
            raise unless fields.size == values.size

            new_node = graph.create_node(
              graph.new_id,
              { synthetic: true, synthetic_class: "TruffleNew", label: label, kind: "alloc" },
            )

            object = [new_node, virtual_node, fields, values]
            objects << object
            virtual_to_object[virtual_id] = object
          end

          # Topological sort of the new nodes in the control flow according to data dependencies
          # There can be cycles (e.g., instances referring one another),
          # so we use TSort.strongly_connected_components instead of TSort.tsort.
          objects = TSort.strongly_connected_components(
            objects.method(:each),
            lambda do |(_new_node, _virtual_node, _fields, values), &b|
              values.each do |value_id|
                usage = virtual_to_object[value_id]
                b.call(usage) if usage
              end
            end,
          ).reduce(:concat)

          prev = control_flow_pred.from
          objects.each do |new_node, virtual_node, fields, values|
            graph.create_edge(prev, new_node, control_flow_pred.props)

            allocated_object_node = virtual_node.outputs.find do |output|
              output.to.node_class.end_with?(".compiler.nodes.virtual.AllocatedObjectNode")
            end
            if allocated_object_node
              allocated_object_node = allocated_object_node.to

              allocated_object_node.outputs.each do |edge|
                graph.create_edge(new_node, edge.to, edge.props)
              end

              allocated_object_node.props[:hidden] = true
            end

            fields.zip(values) do |field, value_id|
              value_node = virtual_to_object[value_id]&.first || graph.nodes[value_id]
              if @options[:hide_null_fields] &&
                  value_node.node_class.end_with?(".compiler.nodes.ConstantNode") &&
                  ["Object[null]", "0"].include?(value_node.props["rawvalue"])
                value_node.props[:hidden] = true
              else
                graph.create_edge(value_node, new_node, { name: field })
              end
            end

            virtual_node.props[:hidden] = true

            prev = new_node
          end
          graph.create_edge(prev, control_flow_next.to, control_flow_next.props)

          commit_allocation_node.props[:hidden] = true
        end
      end

      # Hide reachability fences - they're just really boring.
      def hide_reachability_fences(graph)
        graph.nodes.each_value do |node|
          next unless node.node_class.end_with?(".compiler.nodes.java.ReachabilityFenceNode")

          pred = node.inputs.find { |edge| edge.props[:name] == "next" }
          succ = node.outputs.find { |edge| edge.props[:name] == "next" }

          graph.create_edge(pred.from, succ.to, pred.props.merge({ synthetic: true }))

          node.props[:hidden] = true
          pred.props[:hidden] = true
          succ.props[:hidden] = true
        end
      end

      # If we see these in the graph properties it's probably a Truffle graph.
      TRIGGERS = ["TruffleCompiler", "TruffleFinal"]
    end
  end
end
