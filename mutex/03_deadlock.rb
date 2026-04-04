# Deadlock — two mutexes locked in opposite order by two threads

mutex_a = Mutex.new
mutex_b = Mutex.new

t1 = Thread.new {
  mutex_a.synchronize {
    puts "[T1] locked A, waiting for B..."
    sleep(0.1)  # give T2 time to lock B
    mutex_b.synchronize {
      puts "[T1] locked B — this never prints!"
    }
  }
}

t2 = Thread.new {
  mutex_b.synchronize {
    puts "[T2] locked B, waiting for A..."
    sleep(0.1)  # give T1 time to lock A
    mutex_a.synchronize {
      puts "[T2] locked A — this never prints!"
    }
  }
}

# Wait with timeout to demonstrate the deadlock
result = [t1, t2].map { |t| t.join(2) }

if result.any?(&:nil?)
  puts "\n⛔ DEADLOCK detected! Both threads are stuck."
  puts "T1 holds A, wants B. T2 holds B, wants A."
  puts "\nFix: always lock in the same order (A then B) in both threads."
  t1.kill
  t2.kill
end
