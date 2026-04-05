class TestClass
  def test_method
    yield(1)
  end
end

TestClass.new.test_method { |arg| puts arg }
