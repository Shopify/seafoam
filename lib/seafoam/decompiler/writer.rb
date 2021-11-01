module Seafoam
  module Decompiler
    class Writer
      def initialize(out, width)
        @out = out
        @width = width
        @indent = 0
      end

      def indent
        @indent += 1
        if block_given?
          yield
          @indent -= 1
        end
      end

      def label(line)
        @out.print ' ' * (@indent*@width - @width/2)
        @out.puts line
      end
      
      def line(line=nil)
        @out.print ' ' * @indent * @width
        if block_given?
          yield @out
          @out.puts
        else
          @out.puts line
        end
      end
    end
  end
end
