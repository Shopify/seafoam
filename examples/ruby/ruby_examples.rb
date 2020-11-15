# % ruby --jvm --experimental-options --engine.OSR=false --engine.TraceCompilation --vm.Dgraal.Dump=Truffle:1 ruby_examples.rb

RANDOM = Random.new
EXCEPTION = Exception.new

def example_local_variables(x, y)
  a = x + y
  a * 2 + a
end

def example_local_variables_state(x, y)
  a = x + y
  opaque_call
  a * 2 + a
end

def example_arith_operator(x, y)
  x + y
end

def example_compare_operator(x, y)
  x <= y
end

def example_phi(condition, x)
  if condition
    a = opaque_call_a
  else
    a = opaque_call_b
  end
  a + x
end

def example_simple_call(object, x)
  object.instance_call(x)
end

def example_stamp(x)
  x & 0x1234
end

def example_full_escape(x)
  a = [x]
  escape a
  a[0]
end

def example_no_escape(x)
  a = [x]
  a[0]
end

def example_partial_escape(condition, x)
  a = [x]
  if condition
    escape a
    a[0]
  else
    a[0]
  end
end

def example_if(condition, x, y)
  if condition
    escape x
    a = x
  else
    escape y
    a = y
  end
  a
end

def example_if_never_taken(condition, x, y)
  if condition
    escape x
    a = x
  else
    escape y
    a = y
  end
  a
end

def example_int_switch(value, x, y, z)
  case value
  when 0
    escape x
    a = x
  when 1
    escape y
    a = y
  else
    escape z
    a = z
  end
  a
end

def example_string_switch(value, x, y, z)
  case value
  when 'foo'
    escape x
    a = x
  when 'bar'
    escape y
    a = y
  else
    escape z
    a = z
  end
  a
end

def example_while(count)
  a = count
  while a > 0
    escape a
    a -= 1
  end
  count
end

def example_for(count)
  count.times do |a|
    escape a
  end
end

def example_nested_while(count)
  a = count
  while (a > 0)
    y = count
    while (y > 0)
      escape a
      y -= 1
    end
    a -= 1
  end
  count
end

def example_while_break(count)
  a = count
  while a > 0
    if a == 4
      break
    end
    escape a
    a -= 1
  end
  count
end

def example_raise
  raise EXCEPTION
end

def example_rescue
  begin
    opaque_raise
  rescue Exception => e
    escape e
  end
end

def example_raise_rescue
  begin
    raise EXCEPTION
  rescue Exception => e
    escape e
  end
end

def example_object_allocation(x)
  ExampleObject.new(x)
end

def example_array_allocation(x, y)
  [x, y]
end

def example_field_write(object, x)
  object.x = x
end

def example_field_read(object)
  object.x
end

def example_array_write(array, n, x)
  array[n] = x
end

def example_array_read(array, n)
  array[n]
end

def example_instance_of(x)
  x.is_a?(ExampleObject)
end

# no inline
def opaque_call
  RANDOM.rand(1000)
end

# no inline
def opaque_call_a
  opaque_call
end

# no inline
def opaque_call_b
  opaque_call
end

# no inline
def opaque_raise
  raise EXCEPTION
end

# no inline
def escape(x)
end

# no inline
def static_call(x)
  x
end

class ExampleObject
  attr_accessor :x
  
  def initialize(x)
    @x = x
  end

  # no inline
  def instance_call(y)
    @x + y
  end
end

loop do
  example_local_variables RANDOM.rand(1000), RANDOM.rand(1000)
  example_local_variables_state RANDOM.rand(1000), RANDOM.rand(1000)
  example_arith_operator RANDOM.rand(1000), RANDOM.rand(1000)
  example_compare_operator RANDOM.rand(1000), RANDOM.rand(1000)
  example_phi [true, false].sample, RANDOM.rand(1000)
  example_simple_call ExampleObject.new(RANDOM.rand(1000)), RANDOM.rand(1000)
  example_stamp RANDOM.rand(1000)
  example_full_escape RANDOM.rand(1000)
  example_no_escape RANDOM.rand(1000)
  example_partial_escape [true, false].sample, RANDOM.rand(1000)
  example_if [true, false].sample, RANDOM.rand(1000), RANDOM.rand(1000)
  example_if_never_taken false, RANDOM.rand(1000), RANDOM.rand(1000)
  example_int_switch RANDOM.rand(3), RANDOM.rand(1000), RANDOM.rand(1000), RANDOM.rand(1000)
  example_string_switch ['foo', 'bar', 'baz'].sample, RANDOM.rand(1000), RANDOM.rand(1000), RANDOM.rand(1000)
  example_while RANDOM.rand(10)
  example_for RANDOM.rand(10)
  example_nested_while RANDOM.rand(10)
  example_while_break RANDOM.rand(10)
  begin
    example_raise
  rescue Exception => e
    #
  end
  example_rescue
  example_raise_rescue
  example_object_allocation RANDOM.rand(1000)
  example_array_allocation RANDOM.rand(1000), RANDOM.rand(1000)
  example_field_write ExampleObject.new(RANDOM.rand(1000)), RANDOM.rand(1000)
  example_field_read ExampleObject.new(RANDOM.rand(1000))
  example_array_write [RANDOM.rand(1000), RANDOM.rand(1000), RANDOM.rand(1000)], RANDOM.rand(3), RANDOM.rand(1000)
  example_array_read [RANDOM.rand(1000), RANDOM.rand(1000), RANDOM.rand(1000)], RANDOM.rand(3)
  example_instance_of [Object.new, ExampleObject.new(0)].sample
end
