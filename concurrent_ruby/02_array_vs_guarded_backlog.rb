require "concurrent"

# =============================================================================
# Why the backlog Array needs a Mutex.
#
# The tempting wrong answer is "MRI has a GVL, Array is safe". Each single
# Array operation is safe. The bug lives in CHECK-THEN-ACT:
#
#     index = backlog.index { ... }   # look
#     backlog.delete_at(index)        # act  <- list may have moved by now
#
# That is exactly Lane#delete and Lane#reorder. If a worker shifts the head
# between the two lines, every index shifts down by one and delete_at removes
# the WRONG JOB — a job nobody cancelled silently disappears.
# =============================================================================

JOBS = ("A".."J").to_a

def cancel_the_letter_E(backlog, guard)
  # A web thread cancelling a waiting job.
  guard.call do
    index = backlog.index { |job| job == "E" }
    Thread.pass                      # <- worker gets the GVL here
    backlog.delete_at(index) if index
  end
end

def worker_takes_head(backlog, guard)
  # A pool worker claiming the next job.
  guard.call { backlog.shift }
end

def trial(label, guard_factory)
  survivors = []
  200.times do
    backlog = JOBS.dup
    guard = guard_factory.call
    t1 = Thread.new { cancel_the_letter_E(backlog, guard) }
    t2 = Thread.new { worker_takes_head(backlog, guard) }
    [t1, t2].each(&:join)
    # "E" was cancelled and "A" was taken by the worker. Anything else missing
    # (or an "E" still present) means delete_at hit the wrong element.
    survivors << backlog if backlog.include?("E") || backlog.size != 8
  end
  puts format("  %-22s corrupted %3d / 200 runs", label, survivors.size)
  puts format("  %-22s e.g. %p", "", survivors.first) if survivors.first
end

puts "backlog starts as #{JOBS.inspect}"
puts "worker takes the head (A), a web thread cancels E => expect 8 left, no E\n\n"

# --- unguarded: check-then-act tears --------------------------------------
no_lock = -> { ->(&blk) { blk.call } }
trial("raw Array", no_lock)

# --- guarded: the pair is one atomic step ---------------------------------
with_lock = -> {
  m = Mutex.new
  ->(&blk) { m.synchronize { blk.call } }
}
trial("Mutex-guarded", with_lock)

puts
puts "Note Thread.pass only makes the window reliable; without it the same"
puts "race just fires rarely, which is worse - it looks fine in dev."
