class Parent
  @things = []
  THINGS = 'things'
  def self.things
    @things
  end
  def things
    self.class.things
  end
  def localthings
    @things
  end
  def localthings=(localthings)
    @things = localthings
  end
end

class Child < Parent
    @things = []
end

Parent.things << :car
Child.things  << :doll
mom = Parent.new
dad = Parent.new

p Parent.things #=> [:car]
p Child.things  #=> [:doll]
p mom.things    #=> [:car]
p dad.things    #=> [:car]
dad.localthings = 'localcardad'
mom.localthings = 'localcarmom'
p mom.localthings
p dad.localthings
p mom.things    #=> [:car]
p dad.things    #=> [:car]
p Parent::THINGS
p Child::THINGS
