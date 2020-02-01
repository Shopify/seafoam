# % ruby --experimental-options --engine.CompileOnly=matmult --engine.Inlining=false --engine.OSR=false --vm.Dgraal.Dump=Truffle:2 matmult.rb 100

def matmult(size, a, b, c)
  # Normally we'd write a loop with blocks, but then we'd be reliant on
  # inlining.
  i = 0
  while i < size
    j = 0
    while j < size
      k = 0
      while k < size
        c[i][j] += a[i][k] * b[k][j]
        k += 1
      end
      j += 1
    end
    i += 1
  end
end

loop do
  ARGV.each do |arg|
    size = Integer(arg)
    a = size.times.map { size.times.map { rand } }
    b = size.times.map { size.times.map { rand } }
    c = size.times.map { size.times.map { 0.0 } }
    matmult size, a, b, c
  end
end
