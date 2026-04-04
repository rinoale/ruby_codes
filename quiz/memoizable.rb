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

    def memoize(method_name)
      @memoize_list[method_name] = instance_method(method_name)

      define_method method_name do |*args|
        @cache[[method_name, args]] ||= begin
                                              @call_count[method_name] += 1
                                              self.class.instance_variable_get(:@memoize_list)[method_name].bind(self).call(*args)
                                            end
      end
    end
  end
end

class MathService
  include Memoizable

  def fibonacci(n)
    return n if n <= 1
    fibonacci(n - 1) + fibonacci(n - 2)
  end

  memoize :fibonacci
end

svc = MathService.new
svc.fibonacci(100)     # computes instantly, not billions of calls
svc.call_count(:fibonacci)  # => 101 (only computed each n once: 0..100)
svc.fibonacci(100)     # cached
pp svc.call_count(:fibonacci)  # => 101 (no additional calls)
