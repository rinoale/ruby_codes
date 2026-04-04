# signal vs broadcast — when to use which
#
# signal:    wakes ONE waiting thread (use when one thread can proceed)
# broadcast: wakes ALL waiting threads (use when condition change affects everyone)

mutex = Mutex.new
cv = ConditionVariable.new
ready = false

puts "=== signal: wakes ONE thread ==="

waiters = 3.times.map { |i|
  Thread.new {
    mutex.synchronize {
      cv.wait(mutex) until ready
      puts "  Thread #{i} woke up!"
    }
  }
}

sleep(0.2)
mutex.synchronize {
  ready = true
  cv.signal  # only ONE thread wakes up
}
sleep(0.5)
puts "  (other threads still sleeping)"

# Clean up
ready = false
mutex.synchronize { cv.broadcast }
waiters.each { |t| t.join(1)&.kill rescue nil }

puts "\n=== broadcast: wakes ALL threads ==="

gate_open = false

waiters = 3.times.map { |i|
  Thread.new {
    mutex.synchronize {
      cv.wait(mutex) until gate_open
      puts "  Thread #{i} woke up!"
    }
  }
}

sleep(0.2)
mutex.synchronize {
  gate_open = true
  cv.broadcast  # ALL threads wake up
}
waiters.each(&:join)

puts "\nUse signal for: producer-consumer (one item, one consumer)"
puts "Use broadcast for: gate/barrier (everyone can proceed)"
