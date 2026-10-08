require "concurrent"

# =============================================================================
# One shared pool (Rails' stock AsyncAdapter) vs one pool per queue.
#
# ActiveJob's AsyncAdapter takes a queue_name argument and throws it away:
#
#     def enqueue(job, queue_name:)
#       executor.post(job, &:perform)      # queue_name unused
#     end
#
# So `queue_as :serial` changes nothing about WHERE the job runs. Every job
# shares one pool, and slow jobs starve quick ones. Giving each queue its own
# ThreadPoolExecutor is the entire point of a per-queue adapter.
# =============================================================================

SLOW = 0.30
QUICK = 0.05

def stopwatch
  t0 = Concurrent.monotonic_time
  yield
  Concurrent.monotonic_time - t0
end

def job(log, label, duration, started)
  -> {
    sleep duration
    log << [label, (Concurrent.monotonic_time - started).round(2)]
  }
end

def report(title, log, elapsed)
  puts "#{title} (total #{elapsed.round(2)}s)"
  log.each { |label, at| puts format("    %-10s finished at %.2fs", label, at) }
  puts
end

# --- A. one shared pool ----------------------------------------------------
# 2 workers. The two slow jobs seize both of them, so every quick job waits
# out the full slow job even though the quick work is unrelated.
log = Concurrent::Array.new
elapsed = stopwatch do
  started = Concurrent.monotonic_time
  pool = Concurrent::ThreadPoolExecutor.new(min_threads: 0, max_threads: 2, max_queue: 0)
  2.times { |i| pool.post(&job(log, "slow#{i}", SLOW, started)) }
  4.times { |i| pool.post(&job(log, "quick#{i}", QUICK, started)) }
  pool.shutdown
  pool.wait_for_termination
end
report("A. shared pool, max_threads: 2", log, elapsed)

# --- B. a pool per queue ---------------------------------------------------
# serial: max_threads 1 -> strictly one at a time, in order.
# default: max_threads 4 -> quick jobs run immediately, unaffected by serial.
log = Concurrent::Array.new
elapsed = stopwatch do
  started = Concurrent.monotonic_time
  lanes = {
    "serial"  => Concurrent::ThreadPoolExecutor.new(min_threads: 0, max_threads: 1, max_queue: 0),
    "default" => Concurrent::ThreadPoolExecutor.new(min_threads: 0, max_threads: 4, max_queue: 0)
  }
  2.times { |i| lanes["serial"].post(&job(log, "slow#{i}", SLOW, started)) }
  4.times { |i| lanes["default"].post(&job(log, "quick#{i}", QUICK, started)) }
  lanes.each_value(&:shutdown)
  lanes.each_value(&:wait_for_termination)
end
report("B. per-queue pools (serial: 1, default: 4)", log, elapsed)

puts "A: quick jobs are stuck behind slow ones - one pool, shared starvation."
puts "B: quick jobs finish at ~#{QUICK}s; the serial queue grinds on alone."
puts

# =============================================================================
# min_threads: 0 + idletime -> an idle queue holds NO threads.
# Worth knowing because the dashboard reads @executor.length as "workers".
# =============================================================================
pool = Concurrent::ThreadPoolExecutor.new(min_threads: 0, max_threads: 4, idletime: 60, max_queue: 0)
puts format("fresh pool      length=%d  max_length=%d", pool.length, pool.max_length)
4.times { pool.post { sleep 0.1 } }
sleep 0.02
puts format("while busy      length=%d  max_length=%d", pool.length, pool.max_length)
pool.shutdown
pool.wait_for_termination
puts "so a queue sitting at 0 workers is idle, not broken."
