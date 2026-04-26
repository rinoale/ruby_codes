# Advanced #18: Implement #deep_merge for Nested Hashes
# 
# Build a method that recursively merges two hashes. When both sides have a hash at the same key, merge them recursively instead of overwriting.
# 
# Requirements:
# 
# - deep_merge(base, override) — returns a new merged hash (don't mutate inputs)
# - When both values are hashes → merge recursively
# - When both values are arrays → concatenate
# - Otherwise → override wins
# - Must handle arbitrarily deep nesting
# 
# Example:

def deep_merge(base, override, result = {})
  total_keys = base.keys + override.keys

  total_keys.each do |k|
    base_value = base[k]
    override_value = override[k]

    value_class = (base_value && base_value.class || override_value.class)

    if value_class == Hash
      result[k] = deep_merge(base_value || {}, override_value || {}, result[k] ||= {})
    elsif value_class == Array
      result[k] = (base_value || []) + (override_value || [])
    else
      result[k] = override_value.nil? ? base_value : override_value
    end

    # Q: Why the case not working?
    #
    # case (base_value && base_value.class || override_value.class)
    # when Hash   → Hash === Hash → false!
    #
    # Ruby's case/when calls: when_value === case_value
    # Each class defines === differently:
    #
    #   Hash === {a: 1}     → true  (is {a: 1} an instance of Hash? yes)
    #   Hash === Hash       → false (is Hash an instance of Hash? no, it's a Class)
    #   /abc/ === "xabcx"   → true  (regex match)
    #   (1..5) === 3        → true  (range inclusion)
    #   "a" === "a"         → true  (falls back to ==)
    #
    # The fix: pass an instance as the case target, not a class:
    #
    #   case (base_value || override_value)
    #   when Hash   → Hash === {a: 1} → true!
    #   when Array  → Array === [...] → true!
    #   end
    #
    # Rule: classes belong in `when` (left side of ===), not in `case`.
    #   case target     → right side of ===
    #   when check      → left side of ===  → check === target
  end
  result
end

base = {
  server: {
    host: "localhost",
    port: 3000,
    ssl: { enabled: false, cert: "old.pem" }
  },
  database: {
    adapter: "postgres",
    pool: 5
  },
  features: [:auth, :logging]
}

override = {
  server: {
    port: 8080,
    ssl: { enabled: true, key: "new.key" }
  },
  database: {
    pool: 10,
    timeout: 30
  },
  features: [:caching],
  debug: true
}

pp deep_merge(base, override)
# => {
#   server: {
#     host: "localhost",        # kept from base
#     port: 8080,               # overridden
#     ssl: {
#       enabled: true,          # overridden
#       cert: "old.pem",        # kept from base
#       key: "new.key"          # added from override
#     }
#   },
#   database: {
#     adapter: "postgres",      # kept from base
#     pool: 10,                 # overridden
#     timeout: 30               # added from override
#   },
#   features: [:auth, :logging, :caching],  # concatenated
#   debug: true                 # added from override
# }

# Inputs should not be mutated
puts base[:server][:port]  # => 3000 (unchanged)
