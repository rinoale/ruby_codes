# Read-Write Lock
# Multiple readers can read simultaneously
# Writers need exclusive access — no readers or other writers

class ReadWriteLock
  def initialize
    @mutex = Mutex.new
    @cv = ConditionVariable.new
    @readers = 0
    @writing = false
  end

  def read_lock
    @mutex.synchronize {
      @cv.wait(@mutex) while @writing  # wait if someone is writing
      @readers += 1
    }
    yield
  ensure
    @mutex.synchronize {
      @readers -= 1
      @cv.broadcast if @readers == 0  # wake waiting writers
    }
  end

  def write_lock
    @mutex.synchronize {
      @cv.wait(@mutex) while @writing || @readers > 0
      @writing = true
    }
    yield
  ensure
    @mutex.synchronize {
      @writing = false
      @cv.broadcast  # wake all waiting readers and writers
    }
  end
end

# Shared data
lock = ReadWriteLock.new
data = { value: 0 }

threads = []

# 5 reader threads — can run concurrently
5.times { |i|
  threads << Thread.new {
    3.times {
      lock.read_lock {
        puts "[Reader #{i}] read: #{data[:value]} (concurrent reads OK)"
        sleep(0.05)
      }
    }
  }
}

# 2 writer threads — need exclusive access
2.times { |i|
  threads << Thread.new {
    2.times { |j|
      lock.write_lock {
        data[:value] += 1
        puts "[Writer #{i}] wrote: #{data[:value]} (exclusive)"
        sleep(0.1)
      }
    }
  }
}

threads.each(&:join)
puts "\nFinal value: #{data[:value]}"
