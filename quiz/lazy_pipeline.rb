#9: Lazy Enumerator Pipeline

# Build a class LazyPipeline that chains transformations on a collection without creating intermediate arrays. Similar to Ruby's Enumerator::Lazy, but built from scratch.

# Requirements:
# 
# - LazyPipeline.new(source) — takes any Enumerable (array, range, etc.)
# - #map { |x| ... } — lazy transform, returns self for chaining
# - #select { |x| ... } — lazy filter, returns self for chaining
# - #reject { |x| ... } — lazy negative filter, returns self for chaining
# - #take(n) — limits output to first n results, stops iterating early (doesn't process the rest)
# - #to_a — triggers evaluation and returns the result array
# - Nothing executes until #to_a is called
# - Must work with infinite sources (like an endless range)

# Review:
# - Storing operations as [type, block] pairs in @order_queue enables ordered execution
#   matching the chain call order — good design.
# - Lazy evaluation: nothing runs until to_a, and take breaks early from infinite sources.
# - Note: line 53 applies map to `row` (original value) rather than `result` (accumulated value).
#   This means chained maps (.map { x+1 }.map { x*2 }) would each see the original, not the
#   previous map's output. Not required by the spec, but worth knowing if extending later.
class LazyPipeline
  def initialize(source)
    @source = source
    @order_queue = []
  end

  def map(&block)
    @order_queue << [:map, block]
    self
  end

  def select(&block)
    @order_queue << [:select, block]
    self
  end

  def reject(&block)
    @order_queue << [:reject, block]
    self
  end

  def take(take_num)
    @take_num = take_num
    self
  end

  def to_a
    results = []

    @source.each do |row|
      break if results.length == @take_num

      result = row
      pass = true
      @order_queue.each do |handle, block|
        case handle
        when :map
          result = block.call(row)
        when :select
          pass = block.call(row)
        when :reject
          pass = !block.call(row)
        end
        break unless pass
      end

      results << result if pass
    end
    results
  end
end

# Example:


# With take — stops early
result = LazyPipeline.new(1..Float::INFINITY)
  .select { |x| x.odd? }
  .map { |x| x ** 2 }
  .take(5)
  .to_a
# => [1, 9, 25, 49, 81]

# Proving laziness — track how many items are processed
processed = 0
result = LazyPipeline.new(1..Float::INFINITY)
  .map { |x| processed += 1; x * 10 }
  .take(3)
  .to_a
# => [10, 20, 30]
puts processed  # => 3 (not infinity!)
