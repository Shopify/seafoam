require 'stringio'

module Seafoam
  module Binary
    # Factory for binary readers based on the input.
    module BinaryReader
      def self.for(source)
        case source
        when File
          IOBinaryReader.new(StringIO.new(File.read(source)))
        when IO
          IOBinaryReader.new(source)
        when String
          IOBinaryReader.new(StringIO.new(source))
        else
          raise source.class
        end
      end
    end
  end
end
