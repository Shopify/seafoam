module Seafoam
  # Schedules when floating nodes should run by adding a schedule edge to a
  # fixed node. Nodes are scheduled at the latest node that dominates to all
  # user. A schedule edge means that the attached node should be run before
  # the fixed node it is attached to. The scheduler relies on control edge
  # annotations. Inlined nodes are not scheduled. Hidden nodes are ignored.
  class Scheduler
    def initialize(graph)
      @graph = graph
      @dominator = Dominator.new(@graph)
    end

    def schedule
      # This isn't going to work if there's no control flow edges.
      raise 'no control flow in graph' if @graph.edges.none? { |edge| edge.props[:kind] == 'control' }

      # Later on we'll want a list of branch nodes, and we also count the start
      # node as a branch for this purpose.
      branches = @graph.nodes.values.select { |node|
        control_in = node.inputs.count { |edge| edge.props[:kind] == 'control' }
        countrol_out = node.outputs.count { |edge| edge.props[:kind] == 'control' }
        is_start = control_in == 0 && countrol_out == 1
        is_branch = countrol_out > 1
        is_start || is_branch
      }

      # Create a worklist of nodes that we need to schedule - floating nodes
      # that aren't inlined or hidden.
      to_schedule = @graph.nodes.values.filter { |node|
        node.edges.none? { |edge| edge.props[:kind] == 'control' } && !node.props[:inlined] && !node.props[:hidden]
      }

      # Keep working until the worklist is empty.
      until to_schedule.empty?
        # Take a node from the front of the worklist.
        node = to_schedule.shift

        node_class = node.props.dig(:node_class, :node_class)
        if node_class == 'org.graalvm.compiler.nodes.ValuePhiNode'
          @graph.create_edge node, node.inputs.find { |edge| edge.props[:kind] == 'info' }.from, { kind: 'schedule' }
          next
        end

        # Get users that aren't hidden.
        users = node.outputs.map(&:to).filter { |user| !user.props[:hidden] }.uniq
        # Are there any users not scheduled yet themselves?
        if users.any? { |user| to_schedule.include?(user) }
          # If so, add this node back to the end of the worklist to try again later.
          to_schedule.push node
        else
          if users.size == 1
            # If there's just one user, it's easy - schedule it before the user.
            @graph.create_edge node, users.first, { kind: 'schedule' }
          else
            # We've got multiple users - we need to find where to a common node
            # that dominates all the users to schedule it before.

            inputs = node.inputs.map(&:from).filter { |input| input.edges.any? { |edge| edge.props[:kind] == 'control' } && !input.props[:hidden] }.uniq

            # For each input, walk back through the schedule to find the fixed
            # node that they're eventually scheduled before.
            fixed_inputs = inputs.map { |input|
              fixed_input = input
              until fixed_input.edges.any? { |edge| edge.props[:kind] == 'control' }
                fixed_input = fixed_input.outputs.first { |edge| edge.props[:kind] == 'schedule' }.to
              end
              fixed_input
            }.uniq

            # For each output, walk back through the schedule to find the fixed
            # node that they're eventually scheduled before.
            fixed_outputs = users.map { |user|
              fixed_output = user
              until fixed_output.edges.any? { |edge| edge.props[:kind] == 'control' }
                fixed_output = fixed_output.outputs.first { |edge| edge.props[:kind] == 'schedule' }.to
              end
              fixed_output
            }.uniq

            # We'll only consider scheduling before a branch. It's possible that
            # all users are scheduled to a linear sequence of fixed nodes, in
            # which case going all the way back to the branch to schedule it is
            # not as late as possible. However it's still valid, and simpler to
            # write.

            # Find all branches that dominate all the fixed outputs, and are
            # dominated by all the fixed inputs.
            dominating_branches = branches.select { |branch|
              dominates_outputs = fixed_outputs.all? { |fixed_output| @dominator.dominates?(branch, fixed_output) }
              dominated_by_inputs = fixed_inputs.all? { |fixed_input| @dominator.dominates?(fixed_input, branch) }
              dominates_outputs && dominated_by_inputs
            }

            # Filter the dominating branches to those themselves dominated by
            # all

            # Pick any of the dominating branches, doesn't matter which for
            # now.
            dominating_branch = dominating_branches.first
            raise unless dominating_branch

            @graph.create_edge node, dominating_branch, { kind: 'schedule' }
          end
        end
      end
    end
  end
end
