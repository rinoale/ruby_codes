require "concurrent"

# =============================================================================
# Concurrent::AtomicFixnum vs `counter += 1`
#
# `counter += 1` is THREE operations: read, add, write. MRI's GVL makes each
# bytecode atomic but NOT the sequence — a thread can lose the GVL between the
# read and the write, and then two threads write back the same value.
#
# Thread.pass below just forces that interleaving to happen every time instead
# of once in a million runs. The bug is real without it; it's only rare.
# =============================================================================

THREADS = 8
INCREMENTS = 500
EXPECTED = THREADS * INCREMENTS

puts "expecting #{EXPECTED} in every case\n\n"

# --- 1. plain += : loses updates -------------------------------------------
counter = 0
THREADS.times.map {
  Thread.new {
    INCREMENTS.times {
      tmp = counter      # read
      Thread.pass        # <- GVL handoff right in the middle
      counter = tmp + 1  # write back a stale value
    }
  }
}.each(&:join)
puts format("plain +=          => %5d  %s", counter, counter == EXPECTED ? "ok" : "LOST #{EXPECTED - counter} UPDATES")

# --- 2. Mutex : correct, but every increment contends for the lock ----------
counter = 0
mutex = Mutex.new
THREADS.times.map {
  Thread.new {
    INCREMENTS.times {
      mutex.synchronize {
        tmp = counter
        Thread.pass
        counter = tmp + 1
      }
    }
  }
}.each(&:join)
puts format("Mutex             => %5d  %s", counter, counter == EXPECTED ? "ok" : "LOST")

# --- 3. AtomicFixnum : correct, lock-free ----------------------------------
# Compare-and-swap in a retry loop down in the VM. No lock to queue behind.
atomic = Concurrent::AtomicFixnum.new
THREADS.times.map {
  Thread.new {
    INCREMENTS.times {
      Thread.pass
      atomic.increment
    }
  }
}.each(&:join)
puts format("AtomicFixnum      => %5d  %s", atomic.value, atomic.value == EXPECTED ? "ok" : "LOST")

# =============================================================================
# Why the adapter uses AtomicFixnum for @completed and a Mutex for @backlog:
#
#   @completed is ONE number touched by one operation (increment). CAS covers
#   it, and it stays off the backlog lock — a worker finishing a job must not
#   block a web thread that is pushing or cancelling.
#
#   @backlog is a multi-step invariant (find an index, THEN delete at it).
#   No atomic covers that; see 02.
# =============================================================================
