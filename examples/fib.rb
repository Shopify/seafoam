# % ruby --experimental-options --engine.CompileOnly=fib --engine.Inlining=false --engine.OSR=false --vm.Dgraal.Dump=Truffle:2 fib.rb 14

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
