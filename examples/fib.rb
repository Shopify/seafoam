# $ ruby --vm.Dgraal.TruffleCompileOnly=fib --vm.Dgraal.TruffleFunctionInlining=false --vm.Dgraal.Dump=Truffle:1 fib.rb 14

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
