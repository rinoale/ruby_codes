# =============================================================================
# Ruby Callbacks & Class Structure Methods Reference
# =============================================================================
#
# Ruby provides hooks (callbacks) that fire at specific moments in the lifecycle
# of classes and modules. These are the foundation of metaprogramming and how
# frameworks like Rails build their DSLs (has_many, before_action, validates, etc.)
#
# -----------------------------------------------------------------------------
# 1. Module Lifecycle Hooks
# -----------------------------------------------------------------------------
#
# ▸ included(base)
#   Fires when the module is included into a class.
#   `base` is the class that did the including.
#
#     module Logging
#       def self.included(base)
#         puts "#{self} was included into #{base}"
#         base.extend(ClassMethods)       # add class-level methods
#         base.prepend(Initializer)       # wrap initialize
#       end
#     end
#
#     class App
#       include Logging  # => "Logging was included into App"
#     end
#
# ▸ extended(base)
#   Fires when the module is used to extend an object (usually a class).
#   `base` is the object being extended.
#
#     module ClassMethods
#       def self.extended(base)
#         base.instance_variable_set(:@registry, [])
#       end
#
#       def register(name)
#         @registry << name
#       end
#     end
#
#     class Plugin
#       extend ClassMethods  # => @registry initialized to []
#       register :auth       # works because register is now a class method
#     end
#
# ▸ prepended(base)
#   Fires when the module is prepended. Prepend inserts the module BEFORE the
#   class in the method lookup chain, so it can wrap/override methods while
#   still calling `super` to reach the original.
#
#     module Timing
#       def self.prepended(base)
#         puts "#{self} prepended to #{base}"
#       end
#
#       def slow_method
#         start = Time.now
#         result = super              # calls the original class method
#         puts "Took #{Time.now - start}s"
#         result
#       end
#     end
#
# -----------------------------------------------------------------------------
# 2. Method Lifecycle Hooks
# -----------------------------------------------------------------------------
#
# ▸ method_added(method_name)
#   Fires on a class/module when an instance method is defined.
#   This is how we implement "hoisting" — register intent first, act when
#   the method appears.
#
#     class Base
#       def self.method_added(name)
#         puts "Method defined: #{name}"
#       end
#
#       def hello; end  # => "Method defined: hello"
#     end
#
#   ⚠️  define_method inside method_added triggers it again — use a guard!
#
# ▸ method_removed(method_name)
#   Fires when `remove_method` is called.
#
#     class Foo
#       def self.method_removed(name)
#         puts "Removed: #{name}"
#       end
#       def bar; end
#       remove_method :bar  # => "Removed: bar"
#     end
#
# ▸ method_undefined(method_name)
#   Fires when `undef_method` is called. Unlike remove_method, undef_method
#   prevents the method from being found even in ancestors.
#
# ▸ singleton_method_added(method_name)
#   Fires when a class/singleton method is defined (def self.foo).
#
# -----------------------------------------------------------------------------
# 3. Class Lifecycle Hooks
# -----------------------------------------------------------------------------
#
# ▸ inherited(subclass)
#   Fires on a class when it is subclassed. Only works on classes, not modules.
#
#     class Base
#       def self.inherited(subclass)
#         puts "#{subclass} inherits from #{self}"
#         subclass.instance_variable_set(:@config, {})
#       end
#     end
#
#     class Child < Base; end  # => "Child inherits from Base"
#
#   Rails uses this in ApplicationRecord, ApplicationController, etc.
#
# -----------------------------------------------------------------------------
# 4. Missing/Dynamic Hooks
# -----------------------------------------------------------------------------
#
# ▸ method_missing(name, *args, &block)
#   Fires when a method is called that doesn't exist. Use sparingly.
#
# ▸ respond_to_missing?(name, include_private = false)
#   Must be paired with method_missing so that respond_to? works correctly.
#
# ▸ const_missing(name)
#   Fires when a constant is referenced that doesn't exist.
#   Rails uses this for autoloading: User triggers const_missing,
#   which loads app/models/user.rb.
#
#     module AutoLoad
#       def self.const_missing(name)
#         require name.to_s.downcase
#         const_get(name)
#       end
#     end
#
# -----------------------------------------------------------------------------
# 5. include vs extend vs prepend
# -----------------------------------------------------------------------------
#
#   include:  module methods become INSTANCE methods of the class
#             inserted AFTER the class in the ancestor chain
#
#   extend:   module methods become CLASS methods (singleton methods)
#             often used inside self.included to add DSL methods
#
#   prepend:  module methods become INSTANCE methods, but inserted BEFORE
#             the class in the ancestor chain — can wrap original methods
#             with `super`
#
#   Method lookup order for `prepend M; include N`:
#     PrependedModule → Class → IncludedModule → Superclass → ...
#
# -----------------------------------------------------------------------------
# 6. The Classic Rails Pattern (include + extend + prepend)
# -----------------------------------------------------------------------------
#
#     module Concern
#       def self.included(base)
#         base.extend(ClassMethods)     # DSL: class-level macros
#         base.prepend(InstanceSetup)   # wrap initialize
#         base.class_eval do
#           # execute code in the context of the class
#           attr_accessor :tracked
#         end
#       end
#
#       # Regular instance methods mixed in via include
#       def instance_helper
#         "I'm available on instances"
#       end
#
#       module ClassMethods
#         # Available as class methods
#         def class_helper
#           "I'm available on the class"
#         end
#       end
#
#       module InstanceSetup
#         def initialize(*args)
#           @tracked = true
#           super
#         end
#       end
#     end
#
# =============================================================================

# Review:
# - Good use of prepend for instance variable init and extended for class-level init,
#   avoiding ||= scattered throughout the code.
# - bind(self).call is needed because the original unbound method must be called
#   in the context of the current instance. In Ruby 3.2+, consider bind_call(self, *args)
#   as a single-step alternative.
module Memoizable
  class << self
    def included(base)
      base.extend(ClassMethods)
      base.prepend(Initializer)
    end
  end

  def call_count(method_name)
    @call_count[method_name]
  end

  module Initializer
    def initialize(*args)
      @call_count = Hash.new(0)
      @cache = {}
      # @call_count = {}
      # @call_count.default = 0
      super
    end
  end

  module ClassMethods
    def self.extended(base)
      base.instance_variable_set(:@memoize_list, {})
    end

    def method_added(method_name)
      method_names = instance_variable_get(:@target_methods)
      memoize_list = instance_variable_get(:@memoize_list)
      return if method_names.none?(method_name) || !memoize_list[method_name].nil?

      memoize_list[method_name] = instance_method(method_name)
      define_method method_name do |*args|
        @cache[[method_name, args]] ||= begin
                                          @call_count[method_name] += 1
                                          self.class.instance_variable_get(:@memoize_list)[method_name].bind(self).call(*args)
                                        end
      end
    end

    def memoize(*method_names)
      @target_methods = method_names
    end
  end
end

class MathService
  include Memoizable
  memoize :fibonacci

  def fibonacci(n)
    return n if n <= 1
    fibonacci(n - 1) + fibonacci(n - 2)
  end
end

svc = MathService.new
svc.fibonacci(100)     # computes instantly, not billions of calls
svc.call_count(:fibonacci)  # => 101 (only computed each n once: 0..100)
svc.fibonacci(100)     # cached
pp svc.call_count(:fibonacci)  # => 101 (no additional calls)
