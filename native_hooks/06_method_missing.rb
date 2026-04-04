# method_missing + respond_to_missing? — fires when calling undefined methods
# Always pair them together

class FlexibleConfig
  def initialize
    @data = {}
  end

  def method_missing(name, *args)
    key = name.to_s

    if key.end_with?("=")
      # setter: config.database = "postgres"
      @data[key.chomp("=")] = args.first
    elsif @data.key?(key)
      # getter: config.database
      @data[key]
    else
      super  # important: let unknown methods raise NoMethodError
    end
  end

  def respond_to_missing?(name, include_private = false)
    key = name.to_s
    key.end_with?("=") || @data.key?(key) || super
  end

  def to_s
    @data.inspect
  end
end

config = FlexibleConfig.new
config.database = "postgres"
config.host = "localhost"
config.port = 5432

puts config.database       # => postgres
puts config.host           # => localhost
puts config.port           # => 5432
puts config.respond_to?(:database)  # => true (because respond_to_missing? works)
puts config.respond_to?(:unknown)   # => false

begin
  config.nonexistent  # raises NoMethodError because of `super`
rescue NoMethodError => e
  puts "Caught: #{e.message}"
end
