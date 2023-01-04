# frozen_string_literal: true

module Seafoam
  module Passes
    module TruffleTranslators
      class Default
        def translate_argument_load(index)
          index.to_s
        end
      end
    end
  end
end
