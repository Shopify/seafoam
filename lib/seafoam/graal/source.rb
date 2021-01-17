module Seafoam
  module Graal
    # Routines for understanding source positions in Graal.
    module Source
      def self.render(source_position)
        lines = []
        caller = source_position
        while caller
          method = caller[:method]
          lines.push render_method(method)
          caller = caller[:caller]
        end
        lines.join("\n")
      end

      def self.render_method(method)
        declaring_class = method[:declaring_class]
        name = method[:method_name]
        "#{declaring_class}##{name}"
      end
    end
  end
end
