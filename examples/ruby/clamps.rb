# ruby --experimental-options --engine.CompileOnly=clamp_low,clamp_high --vm.Dgraal.Dump=Truffle:2 --vm.Dgraal.PrintBackendCFG=true clamps.rb 

def clamp_high(min, max, value)
  [min, max, value].sort[1]
end

def clamp_low(min, max, value)
  if value > max
    max
  elsif value < min
    min
  else
    value
  end
end

loop do
  clamp_high(10, 90, rand(100))
  clamp_low(10, 90, rand(100))
end
