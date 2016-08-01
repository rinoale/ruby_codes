module NormalModule
  def self.included base
    base.extend ClassMethods
  end

  def pub_method
    puts 'this is public'
  end

  module ClassMethods
    def cls_method
      puts 'this is class method'
    end
  end

  private

  def prv_method
    puts 'this is private'
  end
end

class NormalClass
  include NormalModule
  puts self.class
end


normal = NormalClass.new


normal.pub_method

normal.class.cls_method

# normal.prv_method

puts normal.class


include NormalModule

prv_method

puts self.class
