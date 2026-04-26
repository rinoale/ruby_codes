queue = Queue.new

dispenser = Thread.new do
  while true do
    sleep(1)
    queue << rand(5)
  end
end

5.times.map do
  Thread.new do
    puts "[#{Thread.current.object_id}] #{queue.pop}"
  end
end.each(&:join)

dispenser.kill

# =============================================================================
# What Ruby's Queue looks like internally.
# Queue is just Mutex + ConditionVariable + Array.
# =============================================================================

class SimpleQueue
  def initialize
    @items = []
    @mutex = Mutex.new
    @cv = ConditionVariable.new
    @closed = false
  end

  # Push an item — never blocks, wakes one waiting thread
  def <<(item)
    @mutex.synchronize {
      raise "queue is closed" if @closed
      @items << item
      @cv.signal    # wake one thread sleeping on pop
    }
  end

  # Pull an item — BLOCKS if empty until something is pushed
  # This is the "invisible wait" that makes Queue useful for threading.
  # Returns nil if queue is closed and empty.
  def pop
    @mutex.synchronize {
      while @items.empty?
        return nil if @closed
        @cv.wait(@mutex)    # release mutex, sleep, re-acquire when woken
      end
      @items.shift
    }
  end

  # Close the queue — no more pushes allowed.
  # Waiting threads wake up and get nil (so they can exit their loops).
  # This replaces "poison pills" — instead of pushing nil per worker,
  # just close the queue.
  def close
    @mutex.synchronize {
      @closed = true
      @cv.broadcast    # wake ALL waiting threads so they see @closed
    }
  end

  def size
    @mutex.synchronize { @items.length }
  end

  def empty?
    @mutex.synchronize { @items.empty? }
  end
end

# === Demo: same behavior as Ruby's Queue ===

puts "\n--- SimpleQueue demo ---"

sq = SimpleQueue.new
results = Array.new(10)

# 3 fixed workers
workers = 3.times.map {
  Thread.new {
    while (task = sq.pop)    # blocks when empty, returns nil when closed
      idx, val = task
      puts "[Worker #{Thread.current.object_id}] processing #{val}"
      sleep(0.1)
      results[idx] = val * 2
    end
    puts "[Worker #{Thread.current.object_id}] exiting"
  }
}

# Push 10 tasks
10.times { |i| sq << [i, i + 1] }

# Close — workers finish remaining tasks then get nil from pop
sq.close

workers.each(&:join)
pp results
# => [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
