# % ruby --jvm --experimental-options --engine.CompileOnly=fib --engine.TraceCompilation --engine.NodeSourcePositions --engine.MultiTier=false --engine.Inlining=false --vm.Dgraal.Dump=Truffle:1 --vm.Dgraal.PrintBackendCFG=true fib.rb 14

def fib(n)
  if n <= 1
    n
  else
    fib(n - 1) + fib(n - 2)
  end
end

loop do
  ARGV.each do |arg|
    fib(Integer(arg))
  end
end
