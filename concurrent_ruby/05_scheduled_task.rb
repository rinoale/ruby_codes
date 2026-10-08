require "concurrent"

# =============================================================================
# Concurrent::ScheduledTask - a timer, not a sleeping thread.
#
# enqueue_at(job, timestamp) gets a FLOAT EPOCH from ActiveJob (Rails already
# called .to_f on it), turns it into a delay, and hands it to a ScheduledTask.
#
#     delay = timestamp - Time.current.to_f
#     return enqueue(job) unless delay.positive?      # already due -> now
#     Concurrent::ScheduledTask.execute(delay) { lane.push(job_data) }
# =============================================================================

def elapsed_since(t0)
  (Concurrent.monotonic_time - t0).round(2)
end

# --- 1. it fires after the delay, on someone else's thread -----------------
t0 = Concurrent.monotonic_time
main = Thread.current.object_id

task = Concurrent::ScheduledTask.execute(0.3) do
  [elapsed_since(t0), Thread.current.object_id]
end

puts "scheduled at 0.0s, waiting..."
at, tid = task.value(5)
puts format("fired at %.2fs on thread %s (main is %s)", at, tid == main ? "MAIN" : "a pool thread", main)
puts

# --- 2. 200 pending timers do NOT cost 200 threads -------------------------
# This is the whole reason a timer beats Thread.new { sleep; run }.
baseline = Thread.list.size
tasks = 200.times.map { Concurrent::ScheduledTask.execute(0.25) { :fired } }
sleep 0.05
while_pending = Thread.list.size
tasks.each { |t| t.value(5) }
after_firing = Thread.list.size

puts "200 ScheduledTasks (baseline #{baseline} threads):"
puts format("    while pending  +%d threads", while_pending - baseline)
puts format("    after firing   +%d threads", after_firing - baseline)

baseline = Thread.list.size
threads = 200.times.map { Thread.new { sleep 0.25 } }
sleep 0.05
while_sleeping = Thread.list.size
puts "200 Thread.new { sleep } (baseline #{baseline} threads):"
puts format("    while sleeping +%d threads", while_sleeping - baseline)
threads.each(&:join)
puts
puts "Waiting is free - the delay is one shared timer, not 200 parked threads."
puts "Threads appear only when tasks FIRE, and they come from a pool that is"
puts "reused and trimmed. That second baseline is high precisely because the"
puts "200 tasks above just fired and left their pool warm."
puts

# --- 3. a past timestamp means "now", not "never" --------------------------
# Mirrors the `return enqueue(job) unless delay.positive?` guard.
def enqueue_at(timestamp, log)
  delay = timestamp - Time.now.to_f
  if delay.positive?
    Concurrent::ScheduledTask.execute(delay) { log << :scheduled }
  else
    log << :immediate
    nil
  end
end

log = Concurrent::Array.new
enqueue_at(Time.now.to_f - 60, log)               # a minute in the past
future = enqueue_at(Time.now.to_f + 0.2, log)     # a fifth of a second out
future&.value(5)
puts "enqueue_at(past)   => #{log[0]}"
puts "enqueue_at(future) => #{log[1]}"
puts

# =============================================================================
# The nuance worth remembering: the ScheduledTask block runs on concurrent-
# ruby's own executor, NOT on your queue's pool. In the adapter that block
# does nothing but `lane.push(job_data)` - one cheap call - and the push then
# posts a token, so the JOB itself still runs on its queue's workers and still
# respects max_workers. If the timer block ran the job directly, a delayed job
# would silently escape its queue's concurrency limit.
# =============================================================================
