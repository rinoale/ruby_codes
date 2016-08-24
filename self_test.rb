def block_test(first, &block)
  puts first
  puts self
  block.call
end

block_test('first') { puts self } 

class TestClass
  def initialize(name, age)
    @name = name
    @age = age
  end

  def testMethod(first, &block)
    puts first
    puts self
    puts self.name
    puts self.age

    block.call
  end

  attr_accessor :name, :age

  def self.testClassMethod(first, &block)
    puts first
    puts self
    puts self.class

    block.call
  end
end

testClass = TestClass.new 'gbsong', 28

testClass.testMethod('test') { puts self }

TestClass.testClassMethod('classMethod') { puts self }

