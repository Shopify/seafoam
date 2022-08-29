require 'tsort'

module Seafoam
  module Passes
    # The Truffle pass applies if it looks like it was compiled by Truffle.
    class TrufflePass < Pass
      def self.applies?(graph)
        graph.props.values.any? do |v|
          TRIGGERS.any? { |t| v.to_s.include?(t) }
        end
      end

      def apply(graph)
        simplify_truffle_args graph if @options[:simplify_truffle_args]
        simplify_alloc graph if @options[:simplify_alloc]
      end

      private

      # Simplify a Truffle argument load into a single, inlined, node very much
      # like a Graal parameter node.
      def simplify_truffle_args(graph)
        graph.nodes.dup.each_value do |node|
          next unless node.node_class == 'org.graalvm.compiler.nodes.java.LoadIndexedNode'

          index_node = node.inputs.find { |edge| edge.props[:name] == 'index' }.from
          array_node = Graal::Pi.follow_pi_object(node.inputs.find { |edge| edge.props[:name] == 'array' }.from)

          next unless index_node.node_class == 'org.graalvm.compiler.nodes.ConstantNode'
          next unless array_node.node_class == 'org.graalvm.compiler.nodes.ParameterNode'

          node.props[:truffle_arg_load] = true

          index = index_node.props['rawvalue']

          arg_node = graph.create_node(graph.new_id, { synthetic: true, inlined: true, label: "T(#{index})", kind: 'input' })

          node.outputs.each do |output|
            next if output.props[:name] == 'next'

            graph.create_edge arg_node, output.to, output.props.dup
            graph.remove_edge output
          end
        end

        graph.nodes.each_value.select { |node| node.props[:truffle_arg_load] }.each do |node|
          control_in = node.inputs.find { |edge| edge.props[:name] == 'next' }
          control_out = node.outputs.find { |edge| edge.props[:name] == 'next' }
          graph.create_edge control_in.from, control_out.to, { name: 'next' }
          graph.remove_edge control_in
          graph.remove_edge control_out
        end
      end

      # Hide nodes that are uninteresting inputs to an allocation node. These
      # are constants that are null or 0.
      def simplify_alloc(graph)
        commit_allocation_nodes = graph.nodes.each_value.select do |node|
          node.node_class == 'org.graalvm.compiler.nodes.virtual.CommitAllocationNode'
        end

        commit_allocation_nodes.each do |commit_allocation_node|
          control_flow_pred = commit_allocation_node.inputs.first
          control_flow_next = commit_allocation_node.outputs.first

          objects = []
          virtual_to_object = {}

          # First step to fill virtual_to_object and avoid ordering issues
          commit_allocation_node.props.each_pair do |key, value|
            if /^object\((\d+)\)$/ =~ key
              virtual_id = $1.to_i
              value =~ /^(\w+(?:\[\])?)\[([0-9,]+)\]$/ or raise value
              class_name, values = $1, $2
              values = values.split(',').map(&:to_i)
              virtual_node = graph.nodes[virtual_id]
              if virtual_node.node_class == 'org.graalvm.compiler.nodes.virtual.VirtualArrayNode'
                label = "New #{class_name[0...-1]}#{virtual_node.props['length']}]"
                fields = values.size.times.to_a
              else
                label = "New #{class_name}"
                fields = virtual_node.props['fields'].map { |field| field[:name] }
              end
              raise unless fields.size == values.size

              new_node = graph.create_node(graph.new_id, { synthetic: true, label: label, kind: 'alloc' })

              object = [new_node, virtual_node, fields, values]
              objects << object
              virtual_to_object[virtual_id] = object
            end
          end

          # Topological sort according to dependencies
          objects = TSort.strongly_connected_components(objects.method(:each),
            -> ((new_node, virtual_node, fields, values), &b) do
              values.each do |value_id|
                usage = virtual_to_object[value_id]
                b.call(usage) if usage
              end
            end).reduce(:concat)

          prev = control_flow_pred.from
          objects.each do |new_node, virtual_node, fields, values|
            graph.create_edge(prev, new_node, control_flow_pred.props)

            allocated_object_node = virtual_node.outputs.find do |output|
              output.to.node_class == 'org.graalvm.compiler.nodes.virtual.AllocatedObjectNode'
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
              if @options[:hide_null_fields] and
                  value_node.node_class == 'org.graalvm.compiler.nodes.ConstantNode' and
                  ['Object[null]', '0'].include?(value_node.props['rawvalue'])
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

      # If we see these in the graph properties it's probably a Truffle graph.
      TRIGGERS = %w[
        TruffleCompiler
      ]
    end
  end
end
