# Mutex Fix — same scenario, now thread-safe

mutex = Mutex.new
counter = 0
delay = 0.001

threads = 100.times.map {
  Thread.new {
    mutex.synchronize {
      sleep(delay)           # even with delay, other threads wait
      current = counter      # only one thread reads at a time
      sleep(delay)
      counter = current + 1  # only one thread writes at a time
    }
  }
}
threads.each(&:join)

puts "Expected: 100"
puts "Got:      #{counter}"
puts "Mutex guarantees correctness regardless of timing"
