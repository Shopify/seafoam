require 'stringio'

module Seafoam
  module BinaryReader
    def self.for(source)
      case source
      when File
        IOBinaryReader.new(File.open(source))
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
