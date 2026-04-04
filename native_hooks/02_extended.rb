# extended(base) — fires when a module extends an object
# Used to add class-level methods (DSL macros)

module Registrable
  def self.extended(base)
    puts "[extended] #{base} extended with #{self}"
    base.instance_variable_set(:@registry, [])
  end

  def register(name)
    @registry << name
  end

  def registered
    @registry
  end
end

class Plugin
  extend Registrable

  register :authentication
  register :logging
  register :caching
end

puts "Registered plugins: #{Plugin.registered.inspect}"
# => [extended] Plugin extended with Registrable
# => Registered plugins: [:authentication, :logging, :caching]
