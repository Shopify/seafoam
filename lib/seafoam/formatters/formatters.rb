module Seafoam
  # Formatters are the mechanism by which `seafoam` command output is presented to the user.
  module Formatters
    autoload :Base, 'seafoam/formatters/base'
    autoload :Json, 'seafoam/formatters/json'
    autoload :Text, 'seafoam/formatters/text'
  end
end
