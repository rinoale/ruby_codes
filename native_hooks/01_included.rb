# included(base) — fires when a module is included into a class
# `base` is the class that did the including

module Greetable
  def self.included(base)
    puts "[included] #{self} was included into #{base}"
    puts "[included] We can set up class-level config here"
    base.instance_variable_set(:@greeting, "Hello")
  end

  def greet(name)
    "#{self.class.instance_variable_get(:@greeting)}, #{name}!"
  end
end

class Person
  include Greetable
end

puts Person.new.greet("Alice")
# => [included] Greetable was included into Person
# => [included] We can set up class-level config here
# => Hello, Alice!
