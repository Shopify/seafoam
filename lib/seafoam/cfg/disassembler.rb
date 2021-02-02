require 'stringio'

module Seafoam
  module CFG
    # Disassemble and print comments from cfg files
    class Disassembler
      def initialize(out)
        @out = out
      rescue StandardError => e
        raise "Unable to open engine: #{e.message}"
      end

      def disassemble(nmethod, print_comments)
        require_crabstone

        comments = nmethod.comments
        comments_n = 0

        case [nmethod.code.arch, nmethod.code.arch_width]
        when %w[AMD64 64]
          crabstone_arch = [Crabstone::ARCH_X86, Crabstone::MODE_64]
        else
          raise "Unknown architecture #{nmethod.code.arch} and bit width #{nmethod.code.arch_width}"
        end

        cs = Crabstone::Disassembler.new(*crabstone_arch)
        begin
          cs.disasm(nmethod.code.code, nmethod.code.base).each do |i|
            if print_comments
              # Print comments associated to the instruction.
              last_comment = i.address + i.bytes.length - nmethod.code.base
              while comments_n < comments.length && comments[comments_n].offset < last_comment
                if comments[comments_n].offset == -1
                  @out.printf("\t\t\t\t;%<comment>s\n", comment: comments[comments_n].comment)
                else
                  @out.printf(
                    "\t\t\t\t;Comment %<loc>i:\t%<comment>s\n",
                    loc: comments[comments_n].offset,
                    comment: comments[comments_n].comment
                  )
                end
                comments_n += 1
              end
            end

            # Print the instruction.
            @out.printf(
              "\t0x%<address>x:\t%<instruction>s\t%<details>s\n",
              address: i.address,
              instruction: i.mnemonic,
              details: i.op_str
            )
          end
        rescue StandardError => e
          raise "Disassembly error: #{e.message}"
        ensure
          cs.close
        end
      end

      def require_crabstone
        require 'crabstone'
      rescue LoadError => e
        if $DEBUG
          raise e
        else
          raise 'Could not load Capstone - is it installed?'
        end
      end
    end
  end
end
