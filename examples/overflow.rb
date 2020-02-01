# % ruby --experimental-options --engine.CompileOnly=add --engine.Inlining=false --engine.OSR=false --vm.Dgraal.Dump=Truffle:2 overflow.rb 1 2 3

# The purpose of this add function is to show what Ruby arithmetic with overflow looks like.

def add(a, b)
  a + b
end

loop do
  ARGV.each do |arg|
    add(Integer(arg), Integer(arg))
  end
end
