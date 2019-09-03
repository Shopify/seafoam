# $ ruby --vm.Dgraal.TruffleCompileOnly=identity --vm.Dgraal.TruffleFunctionInlining=false --vm.Dgraal.Dump=Truffle:1 identity.rb 1 2 3

# The purpose of this identity function is to learn what the Truffle prelude looks like.

def identity(arg)
  arg
end

loop do
  ARGV.each do |arg|
    identity(Integer(arg))
  end
end
