class TestClass
  def method_missing(*args)
    puts "method_missing: #{args}"
    self
  end

  def respond_to_missing?(name, include_all)
    puts name

    false
  end
end

test_class = TestClass.new

pp test_class.asdasd
