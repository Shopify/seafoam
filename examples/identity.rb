# % ruby --experimental-options --engine.CompileOnly=identity --engine.Inlining=false --engine.OSR=false --vm.Dgraal.Dump=Truffle:2 identity.rb 1 2 3

# The purpose of this identity function is to learn what the Truffle prelude looks like.

def identity(arg)
  arg
end

loop do
  ARGV.each do |arg|
    identity(Integer(arg))
  end
end
