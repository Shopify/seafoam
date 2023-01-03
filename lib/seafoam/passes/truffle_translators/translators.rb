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
          translator = node.visit_outputs(:bfs) do |entry|
            declaring_class = entry.props["code"] || entry.props.dig("nodeSourcePosition", :method)

            if declaring_class
              subpackage = declaring_class[:declaring_class].match(/^(\w+\.\w+)\./)[1]
              translator = TRUFFLE_LANGUAGES[subpackage]

              break const_get(translator).new if translator
            end
          end

          translator || Default.new
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
