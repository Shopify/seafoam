# frozen_string_literal: true

module Seafoam
  module Passes
    module TruffleTranslators
      class TruffleRuby < Default
        TRUFFLERUBY_ARGS = [
          "DECLARATION_FRAME",
          "CALLER_SPECIAL_VARIABLES",
          "METHOD",
          "DECLARATION_CONTEXT",
          "FRAME_ON_STACK_MARKER",
          "SELF",
          "BLOCK",
          "DESCRIPTOR",
        ]

        def translate_argument_load(index)
          index >= TRUFFLERUBY_ARGS.size ? "args[#{index - TRUFFLERUBY_ARGS.size}]" : TRUFFLERUBY_ARGS[index]
        end
      end
    end
  end
end
