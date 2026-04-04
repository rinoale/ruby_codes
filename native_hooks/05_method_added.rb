# method_added(name) — fires when an instance method is defined on the class
# This enables "hoisting" — declare intent before the method exists

module Deprecatable
  def self.extended(base)
    base.instance_variable_set(:@deprecated_methods, [])
    base.instance_variable_set(:@wrapped, {})
  end

  def deprecate(*method_names)
    @deprecated_methods = method_names
  end

  def method_added(method_name)
    return unless @deprecated_methods.include?(method_name)
    return if @wrapped[method_name]  # guard against infinite recursion

    @wrapped[method_name] = true
    original = instance_method(method_name)

    define_method(method_name) do |*args, &block|
      warn "[DEPRECATED] #{method_name} is deprecated and will be removed in a future version"
      original.bind_call(self, *args, &block)
    end
  end
end

class OldApi
  extend Deprecatable

  deprecate :legacy_fetch  # declared BEFORE the method — hoisted!

  def legacy_fetch(id)
    "fetched record #{id}"
  end

  def current_fetch(id)
    "fetched record #{id} (new way)"
  end
end

api = OldApi.new
puts api.legacy_fetch(42)     # prints deprecation warning
puts api.current_fetch(42)    # no warning
