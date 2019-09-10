def clamp(min, max, value)
  [min, max, value].sort[1]
end

loop do
  clamp(1, 3, 4)
  clamp(2, 4, 0)
  clamp(4, 8, 5)
end
