module Seafoam
  # An adapter to read binary values from an IO stream.
  class IOBinaryReader
    def initialize(io)
      @io = io
    end

    def read_utf8(length)
      read_bytes(length).force_encoding Encoding::UTF_8
    end

    def read_bytes(length)
      @io.read(length)
    end

    def read_float64
      @io.read(8).unpack1('G')
    end

    def read_float32
      @io.read(4).unpack1('g')
    end

    def read_sint64
      @io.read(8).unpack1('q>')
    end

    def read_sint32
      @io.read(4).unpack1('l>')
    end

    def read_sint16
      @io.read(2).unpack1('s>')
    end

    def read_uint16
      @io.read(2).unpack1('S>')
    end

    def read_sint8
      @io.read(1).unpack1('c')
    end

    def read_uint8
      @io.readbyte
    end

    def peek_sint8
      byte = @io.read(1).unpack1('c')
      @io.ungetbyte byte
      byte
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
      @io.seek count, IO::SEEK_CUR
    end

    def eof?
      @io.eof?
    end
  end
end
