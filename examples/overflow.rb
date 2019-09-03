# $ ruby --vm.Dgraal.TruffleCompileOnly=add --vm.Dgraal.TruffleFunctionInlining=false --vm.Dgraal.Dump=Truffle:1 overflow.rb 1 2 3

# The purpose of this add function is to show what Ruby arithmetic with overflow looks like.

def add(a, b)
  a + b
end

loop do
  ARGV.each do |arg|
    add(Integer(arg), Integer(arg))
  end
end
