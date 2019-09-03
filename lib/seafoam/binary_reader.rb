module Seafoam
  # An adapter to read binary values from an IO stream.
  class BinaryReader
    def initialize(stream)
      @stream = stream
    end

    def read_utf8(length)
      read_bytes(length).force_encoding(Encoding::UTF_8)
    end

    def read_bytes(length)
      @stream.read(length)
    end

    def read_float64
      @stream.read(8).unpack1('G')
    end

    def read_float32
      @stream.read(4).unpack1('g')
    end

    def read_sint64
      @stream.read(8).unpack1('q>')
    end

    def read_sint32
      @stream.read(4).unpack1('l>')
    end

    def read_sint16
      @stream.read(2).unpack1('s>')
    end

    def read_uint16
      @stream.read(2).unpack1('S>')
    end

    def read_sint8
      @stream.read(1).unpack1('c')
    end

    def read_uint8
      @stream.readbyte
    end

    def skip_float64(count = 1)
      skip count * 8
    end

    def skip_float32(count = 1)
      skip count * 4
    end

    def skip_int64(count = 1)
      skip count * 8
    end

    def skip_int32(count = 1)
      skip count * 4
    end

    def skip_int16(count = 1)
      skip count * 2
    end

    def skip_int8(count = 1)
      skip count
    end

    def skip(count)
      @stream.seek(count, IO::SEEK_CUR)
    end

    def eof?
      @stream.eof?
    end
  end
end
