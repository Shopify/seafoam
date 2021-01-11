require 'stringio'
require 'zlib'
require 'crabstone'

module Seafoam
  module CFG
    # Disassemble and print comments from cfg files
    class Disassembler
      def initialize(out)
        @out = out
        @cs = Crabstone::Disassembler.new(Crabstone::ARCH_X86, Crabstone::MODE_64)
      rescue StandardError => e
        raise "Unable to open engine: #{e.message}"
      end

      def disassemble(nmethod, print_comments)
        # 0: no comments printed; 1: single-line comments printed; 2: all comments printed.
        comments = nmethod[:comments]
        comments_at = 0
        comments_length = comments.length

        begin
          # p nmethod[:code][:code].unpack1('H*')
          # p nmethod[:code][:base]
          # nmethod[:code][:base] = 0
          @cs.disasm(nmethod[:code][:code], nmethod[:code][:base]).each do |i|
            # print comments associated to the instruction
            if print_comments.positive?
              last_comment = i.address + i.bytes.length - nmethod[:code][:base]
              while comments_at < comments_length && comments[comments_at][:offset] < last_comment
                if comments[comments_at][:offset] == -1
                  @out.printf("\t\t\t\t;%<comment>s\n", comment: comments[comments_at][:comment]) if print_comments == 2
                else
                  @out.printf(
                    "\t\t\t\t;Comment %<loc>i:\t%<comment>s\n",
                    loc: comments[comments_at][:offset],
                    comment: comments[comments_at][:comment]
                  )
                end
                comments_at += 1
              end
            end

            # print instruction
            @out.printf(
              "0x%<address>x:\t%<instruction>s\t%<details>s\n",
              address: i.address,
              instruction: i.mnemonic,
              # bytes: i.bytes.map { |c| format('%02x', c) }.join(' '),
              details: i.op_str
            )
          end
        rescue StandardError => e
          raise "Disassembly error: #{e.message}"
        ensure
          @cs.close
        end
      end
    end
  end
end
