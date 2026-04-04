# Race Condition — what happens WITHOUT a mutex
# Multiple threads increment a counter, but the result is wrong

counter = 0
delay = 0.001  # simulate I/O to release GIL and expose the bug

threads = 100.times.map {
  Thread.new {
    sleep(delay)       # GIL releases during sleep
    current = counter  # thread A reads 5
    sleep(delay)       # thread B also reads 5
    counter = current + 1  # both write 6 — one increment lost!
  }
}
threads.each(&:join)

puts "Expected: 100"
puts "Got:      #{counter}"
puts "Lost:     #{100 - counter} increments"
