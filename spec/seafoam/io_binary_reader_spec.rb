require 'stringio'

require 'seafoam'

require 'rspec'

describe Seafoam::IOBinaryReader do
  describe '#read_utf8' do
    it 'reads a UTF-8 string' do
      string = 'abc😀'
      reader = Seafoam::IOBinaryReader.new(StringIO.new(string))
      expect(reader.read_utf8(string.bytesize)).to eq string
    end
  end

  describe '#read_bytes' do
    it 'reads bytes' do
      string = 'abc😀'
      reader = Seafoam::IOBinaryReader.new(StringIO.new(string))
      expect(reader.read_bytes(string.bytesize)).to eq "abc\xF0\x9F\x98\x80".force_encoding(Encoding::ASCII_8BIT)
    end
  end

  describe '#read_float64' do
    it 'reads a double-precision float' do
      reader = Seafoam::IOBinaryReader.new(StringIO.new("#{[1.5].pack('G')}hello"))
      expect(reader.read_float64).to eq 1.5
    end
  end

  describe '#read_float32' do
    it 'reads a single-precision float' do
      reader = Seafoam::IOBinaryReader.new(StringIO.new("#{[1.5].pack('g')}hello"))
      expect(reader.read_float32).to eq 1.5
    end
  end

  describe '#read_sint64' do
    it 'reads a signed 64-bit network-endian integer' do
      reader = Seafoam::IOBinaryReader.new(StringIO.new("#{[1234].pack('q>')}hello"))
      expect(reader.read_sint64).to eq 1234
    end
  end

  describe '#read_sint32' do
    it 'reads a signed 32-bit network-endian integer' do
      reader = Seafoam::IOBinaryReader.new(StringIO.new("#{[1234].pack('l>')}hello"))
      expect(reader.read_sint32).to eq 1234
    end
  end

  describe '#read_sint16' do
    it 'reads a signed 16-bit network-endian integer' do
      reader = Seafoam::IOBinaryReader.new(StringIO.new("#{[1234].pack('s>')}hello"))
      expect(reader.read_sint16).to eq 1234
    end
  end

  describe '#read_sint8' do
    it 'reads a signed 8-bit integer' do
      reader = Seafoam::IOBinaryReader.new(StringIO.new("#{[-123].pack('c')}hello"))
      expect(reader.read_sint8).to eq(-123)
    end
  end

  describe '#read_uint8' do
    it 'reads an unsigned 8-bit integer' do
      reader = Seafoam::IOBinaryReader.new(StringIO.new("#{[212].pack('C')}hello"))
      expect(reader.read_uint8).to eq 212
    end
  end

  describe '#skip_float64' do
    it 'skips 8 bytes' do
      reader = Seafoam::IOBinaryReader.new(StringIO.new('12345678x'))
      reader.skip_float64
      expect(reader.read_uint8).to eq 'x'.ord
    end

    it 'accepts a count' do
      reader = Seafoam::IOBinaryReader.new(StringIO.new('1234567812345678x'))
      reader.skip_float64 2
      expect(reader.read_uint8).to eq 'x'.ord
    end
  end

  describe '#skip_float32' do
    it 'skips 4 bytes' do
      reader = Seafoam::IOBinaryReader.new(StringIO.new('1234x'))
      reader.skip_float32
      expect(reader.read_uint8).to eq 'x'.ord
    end

    it 'accepts a count' do
      reader = Seafoam::IOBinaryReader.new(StringIO.new('12341234x'))
      reader.skip_float32 2
      expect(reader.read_uint8).to eq 'x'.ord
    end

    describe '#skip_int64' do
      it 'skips 8 bytes' do
        reader = Seafoam::IOBinaryReader.new(StringIO.new('12345678x'))
        reader.skip_int64
        expect(reader.read_uint8).to eq 'x'.ord
      end

      it 'accepts a count' do
        reader = Seafoam::IOBinaryReader.new(StringIO.new('1234567812345678x'))
        reader.skip_int64 2
        expect(reader.read_uint8).to eq 'x'.ord
      end
    end

    describe '#skip_int32' do
      it 'skips 4 bytes' do
        reader = Seafoam::IOBinaryReader.new(StringIO.new('1234x'))
        reader.skip_int32
        expect(reader.read_uint8).to eq 'x'.ord
      end

      it 'accepts a count' do
        reader = Seafoam::IOBinaryReader.new(StringIO.new('12341234x'))
        reader.skip_int32 2
        expect(reader.read_uint8).to eq 'x'.ord
      end
    end

    describe '#skip_int16' do
      it 'skips 2 bytes' do
        reader = Seafoam::IOBinaryReader.new(StringIO.new('12x'))
        reader.skip_int16
        expect(reader.read_uint8).to eq 'x'.ord
      end

      it 'accepts a count' do
        reader = Seafoam::IOBinaryReader.new(StringIO.new('1212x'))
        reader.skip_int16 2
        expect(reader.read_uint8).to eq 'x'.ord
      end
    end

    describe '#skip_int8' do
      it 'skips 1 byte' do
        reader = Seafoam::IOBinaryReader.new(StringIO.new('1x'))
        reader.skip_int8
        expect(reader.read_uint8).to eq 'x'.ord
      end

      it 'accepts a count' do
        reader = Seafoam::IOBinaryReader.new(StringIO.new('11x'))
        reader.skip_int8 2
        expect(reader.read_uint8).to eq 'x'.ord
      end
    end

    describe '#skip' do
      it 'skips n bytes' do
        reader = Seafoam::IOBinaryReader.new(StringIO.new('123x'))
        reader.skip 3
        expect(reader.read_uint8).to eq 'x'.ord
      end
    end

    describe '#eof?' do
      it 'returns false when not at the end of file' do
        reader = Seafoam::IOBinaryReader.new(StringIO.new('123'))
        expect(reader.eof?).to be false
      end

      it 'returns true when at the end of file' do
        reader = Seafoam::IOBinaryReader.new(StringIO.new(''))
        expect(reader.eof?).to be true
      end
    end
  end
end
