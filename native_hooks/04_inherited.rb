# inherited(subclass) — fires when a class is subclassed
# Only works on classes, not modules
# Rails uses this in ApplicationRecord, ApplicationController

class BaseModel
  @descendants = []

  def self.inherited(subclass)
    puts "[inherited] #{subclass} < #{self}"
    @descendants << subclass
    subclass.instance_variable_set(:@table_name, subclass.name.downcase + "s")
  end

  def self.descendants
    @descendants
  end

  def self.table_name
    @table_name
  end
end

class User < BaseModel; end
class Post < BaseModel; end
class Comment < BaseModel; end

puts "\nAll descendants: #{BaseModel.descendants.inspect}"
puts "User table: #{User.table_name}"
puts "Post table: #{Post.table_name}"
puts "Comment table: #{Comment.table_name}"
