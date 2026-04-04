# Producer-Consumer with ConditionVariable
# Consumers sleep efficiently until producers add items

class WorkQueue
  def initialize
    @queue = []
    @mutex = Mutex.new
    @cv = ConditionVariable.new
  end

  def push(item)
    @mutex.synchronize {
      @queue << item
      puts "  [Producer] pushed: #{item} (queue size: #{@queue.size})"
      @cv.signal  # wake ONE waiting consumer
    }
  end

  def pop
    @mutex.synchronize {
      # Always use `while`, not `if` — guards against spurious wakeups
      @cv.wait(@mutex) while @queue.empty?
      @queue.shift
    }
  end
end

q = WorkQueue.new

# Start 3 consumers FIRST — they'll block waiting for items
consumers = 3.times.map { |i|
  Thread.new {
    item = q.pop  # blocks here until an item is available
    puts "  [Consumer #{i}] got: #{item}"
  }
}

puts "Consumers are waiting..."
sleep(0.5)

# Producer pushes 3 items — each wakes one consumer
puts "\nProducer starting..."
q.push("job_a")
sleep(0.1)
q.push("job_b")
sleep(0.1)
q.push("job_c")

consumers.each(&:join)
puts "\nAll consumers finished"
