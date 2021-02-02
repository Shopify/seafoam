require 'stringio'
require 'zlib'

module Seafoam
  module CFG
    Code = Struct.new(:arch, :arch_width, :base, :code)
    Comment = Struct.new(:offset, :comment)
    NMethod = Struct.new(:code, :comments)

    # A parser for CFG files.
    class CFGParser
      def initialize(out, file)
        @out = out
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
              @cfg_name = Regexp.last_match(1)
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

        arch = nil
        arch_width = nil
        code = nil
        comments = []
        raise unless @reader.readline == "begin_nmethod\n"

        loop do
          line = @reader.readline("\n")
          case line
          when /  Platform (.*) (.*)  <\|\|@\n/
            arch = Regexp.last_match(1)
            arch_width = Regexp.last_match(2)
          when /  HexCode (.*) (.*)  <\|\|@\n/
            base = Regexp.last_match(1).to_i(16)
            code = [Regexp.last_match(2)].pack('H*')
            raise if arch.nil? || arch_width.nil?

            code = Code.new(arch, arch_width, base, code)
          when /  Comment (\d*) (.*)  <\|\|@\n/
            offset = Regexp.last_match(1).to_i
            comment = Regexp.last_match(2)
            comments.push Comment.new(offset, comment)
          when "  <<<HexCodeFile\n"
            next
          when "  HexCodeFile>>> <|@\n"
            next
          when "end_nmethod\n"
            break
          when /  (.*)  <\|\|@\n/
            offset = -1
            comment = Regexp.last_match(1)
            comments.push Comment.new(offset, comment)
          when /  (.*)\n/
            offset = -1
            comment = Regexp.last_match(1)
            comments.push Comment.new(offset, comment)
          else
            # In case anything was missed
            raise 'There is currently no case for this line. Please open an issue so it can be addressed.'
          end
        end
        NMethod.new(code, comments)
      end
    end
  end
end
