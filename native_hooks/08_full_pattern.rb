# The Full Rails-style Pattern
# Combining included + extend + prepend + method_added
# This builds a mini ActiveRecord-like DSL

module Validatable
  def self.included(base)
    base.extend(ClassMethods)
    base.prepend(Initializer)
  end

  module Initializer
    def initialize(**attrs)
      @errors = []
      super
    end
  end

  module ClassMethods
    def self.extended(base)
      base.instance_variable_set(:@validations, [])
    end

    def validates(field, **rules)
      @validations << { field: field, rules: rules }
    end

    def validations
      @validations
    end
  end

  def valid?
    @errors = []

    self.class.validations.each do |v|
      field = v[:field]
      value = send(field)
      rules = v[:rules]

      if rules[:presence] && (value.nil? || value.to_s.empty?)
        @errors << "#{field} can't be blank"
      end

      if rules[:min_length] && value.to_s.length < rules[:min_length]
        @errors << "#{field} must be at least #{rules[:min_length]} characters"
      end

      if rules[:format] && !value.to_s.match?(rules[:format])
        @errors << "#{field} format is invalid"
      end
    end

    @errors.empty?
  end

  def errors
    @errors
  end
end

class User
  include Validatable

  # Looks like Rails!
  validates :name, presence: true, min_length: 2
  validates :email, presence: true, format: /\A[\w.+-]+@[\w-]+\.[\w.]+\z/

  attr_accessor :name, :email

  def initialize(name: nil, email: nil)
    super()
    @name = name
    @email = email
  end
end

puts "=== Valid user ==="
user = User.new(name: "Alice", email: "alice@example.com")
puts "Valid? #{user.valid?}"
puts "Errors: #{user.errors.inspect}"

puts "\n=== Invalid user ==="
bad = User.new(name: "", email: "not-an-email")
puts "Valid? #{bad.valid?}"
puts "Errors: #{bad.errors.inspect}"

puts "\n=== Missing everything ==="
empty = User.new
puts "Valid? #{empty.valid?}"
puts "Errors: #{empty.errors.inspect}"
