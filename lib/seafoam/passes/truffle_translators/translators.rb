# frozen_string_literal: true

require "set"

module Seafoam
  module Passes
    module TruffleTranslators
      autoload :Default, "seafoam/passes/truffle_translators/default"
      autoload :TruffleRuby, "seafoam/passes/truffle_translators/truffleruby"

      TRUFFLE_LANGUAGES = {
        "org.truffleruby" => "TruffleRuby",
      }

      class << self
        def get_translator(node)
          queue = node.outputs.collect(&:to)
          visited = Set.new

          until queue.empty?
            entry = queue.shift
            visited << entry

            declaring_class = (entry.props["code"] || entry.props.dig(
              "nodeSourcePosition",
              :method,
            ))&.[](:declaring_class)

            if declaring_class
              subpackage = declaring_class.match(/^(\w+\.\w+)\./)[1]
              translator = TRUFFLE_LANGUAGES[subpackage]

              return const_get(translator).new if translator
            end

            entry.outputs.collect(&:to).each do |child|
              queue << child unless visited.include?(child)
            end
          end

          Default.new
        end
      end

      class Default
        def translate_argument_load(index)
          index.to_s
        end
      end
    end
  end
end
