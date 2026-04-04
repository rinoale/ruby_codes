class LruCache
  def initialize(max_cap)
    @max_cap = max_cap
    @cache = {}
  end

  def put(*args)
    @cache.delete(args[0])
    @cache.delete(@cache.first&.first) if @cache.length >= @max_cap
    @cache[args[0]] = args[1]
  end

  def get(key)
    return -1 unless @cache[key]

    result = @cache.delete(key)
    @cache[key] = result
  end
end

cache = LruCache.new(2)

pp cache.put(:a, 1)
pp cache.put(:b, 2)
pp cache.get(:a)      # => 1
pp cache.put(:c, 3)   # evicts :b (least recently used)
pp cache.get(:b)      # => -1
pp cache.get(:c)      # => 3
pp cache.put(:d, 4)   # evicts :a
pp cache.get(:a)      # => -1
pp cache.get(:c)      # => 3
pp cache.get(:d)      # => 4
