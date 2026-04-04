# Bounded Buffer — backpressure for fast producers
# Producers block when buffer is full, consumers block when empty
# Uses TWO ConditionVariables — one per condition

class BoundedBuffer
  def initialize(max_size)
    @buf = []
    @max = max_size
    @mutex = Mutex.new
    @not_empty = ConditionVariable.new  # consumers wait on this
    @not_full = ConditionVariable.new   # producers wait on this
  end

  def put(item)
    @mutex.synchronize {
      @not_full.wait(@mutex) while @buf.size >= @max
      @buf << item
      puts "  [put] #{item} (buffer: #{@buf.size}/#{@max})"
      @not_empty.signal  # wake a consumer
    }
  end

  def take
    @mutex.synchronize {
      @not_empty.wait(@mutex) while @buf.empty?
      item = @buf.shift
      puts "  [take] #{item} (buffer: #{@buf.size}/#{@max})"
      @not_full.signal  # wake a producer
      item
    }
  end
end

buf = BoundedBuffer.new(3)  # max 3 items

# Fast producer — tries to push 8 items
producer = Thread.new {
  8.times { |i|
    buf.put("item_#{i}")
    # No sleep — produces as fast as possible
    # Will block when buffer hits 3
  }
  puts "\n[Producer] done"
}

# Slow consumer — takes items slowly
consumer = Thread.new {
  8.times {
    sleep(0.2)  # slow consumer
    buf.take
  }
  puts "[Consumer] done"
}

producer.join
consumer.join
puts "\nBackpressure kept the buffer at max #{3} items"
