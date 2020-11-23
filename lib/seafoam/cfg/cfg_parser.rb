require 'stringio'
require 'zlib'

module Seafoam
  module CFG
    Code = Struct.new(:platform, :base, :code)
    Comment = Struct.new(:offset, :comment)
    NMethod = Struct.new(:code, :comments)

    # A parser for CFG files.
    class CFGParser
      def initialize(file)
        data = File.read(file, encoding: Encoding::ASCII_8BIT)
        if data[0..1].bytes == [0x1f, 0x8b]
          data = Zlib.gunzip(data)
        end
        @reader = StringIO.new(data)
        @state = :any
        @cfg_name = nil
      end

      def skip_over_cfg(name)
        loop do
          line = @reader.readline("\n")
          case line
          when "begin_cfg\n"
            @state = :cfg
            @cfg_name = nil
          when /  name "(.*)"\n/
            if @state == :cfg
              @cfg_name = $1
            end
          when "end_cfg\n"
            raise unless @state == :cfg
            @state = :any
            break if @cfg_name == name
          else
            next
          end
        end
      end

      def read_nmethod
        raise unless @state == :any
        code = nil
        comments = []
        raise unless @reader.readline == "begin_nmethod\n"
        loop do
          line = @reader.readline("\n")
          case line
          when /  Platform (.*) (.*)  <\|\|@\n/
            raise unless $1 == 'AMD64'
            raise unless $2 == '64'
          when /  HexCode (.*) (.*)  <\|\|@\n/
            base = $1.to_i(16)
            code = $2.unpack1('H*')
            code = Code.new('amd64', base, code)
          when /  Comment (\d*) (.*)  <\|\|@\n/
            offset = $1.to_i
            comment = $2
            comments.push Comment.new(offset, comment)
          when "  <<<HexCodeFile\n"
            next
          when "HexCodeFile>>> <|@\n"
            next
          when "end_nmethod\n"
            break
          else
            # useful info here :(
          end
        end
        NMethod.new(code, comments)
      end
    end
  end
end
