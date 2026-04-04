# =============================================================================
# Mutex & ConditionVariable Reference
# =============================================================================
#
# -----------------------------------------------------------------------------
# 1. Mutex Basics
# -----------------------------------------------------------------------------
#
# A Mutex (mutual exclusion) ensures only one thread executes a critical
# section at a time. Without it, concurrent reads/writes to shared state
# can interleave and corrupt data.
#
#   mutex = Mutex.new
#   counter = 0
#
#   # UNSAFE — race condition
#   10.times.map { Thread.new { counter += 1 } }.each(&:join)
#   # counter may not be 10!
#
#   # SAFE — mutex protects the critical section
#   10.times.map {
#     Thread.new { mutex.synchronize { counter += 1 } }
#   }.each(&:join)
#   # counter is guaranteed to be 10
#
# ⚠️  Never nest synchronize on the SAME mutex — it deadlocks:
#
#   mutex.synchronize {
#     mutex.synchronize { }  # => deadlock! (ThreadError)
#   }
#
# If methods call each other, lock at the outermost level only, and use
# private unlocked helpers internally.
#
# -----------------------------------------------------------------------------
# 2. ConditionVariable — "wait until something changes"
# -----------------------------------------------------------------------------
#
# A ConditionVariable lets a thread SLEEP inside a mutex and be WOKEN UP
# by another thread when a condition changes. This avoids busy-waiting
# (polling in a loop with sleep).
#
#   mutex = Mutex.new
#   cv = ConditionVariable.new
#   ready = false
#
#   # Consumer thread — waits for data
#   consumer = Thread.new {
#     mutex.synchronize {
#       cv.wait(mutex) until ready    # sleeps, releases mutex
#       puts "Data is ready!"         # wakes up here
#     }
#   }
#
#   # Producer thread — prepares data
#   sleep(1)
#   mutex.synchronize {
#     ready = true
#     cv.signal                       # wakes up ONE waiting thread
#   }
#
#   consumer.join
#
# Key methods:
#   cv.wait(mutex)      — releases mutex, sleeps, re-acquires mutex on wake
#   cv.signal           — wakes up ONE waiting thread
#   cv.broadcast        — wakes up ALL waiting threads
#
# ⚠️  Always use `wait` inside a `while` loop, not `if`:
#
#   # WRONG — spurious wakeup could skip the check
#   cv.wait(mutex) if queue.empty?
#
#   # RIGHT — re-checks condition after waking
#   cv.wait(mutex) while queue.empty?
#
# -----------------------------------------------------------------------------
# 3. Example: Producer-Consumer Queue
# -----------------------------------------------------------------------------
#
# A thread-safe queue where producers add items and consumers take them.
# Consumers block when the queue is empty.
#
#   class WorkQueue
#     def initialize
#       @queue = []
#       @mutex = Mutex.new
#       @cv = ConditionVariable.new
#     end
#
#     def push(item)
#       @mutex.synchronize {
#         @queue << item
#         @cv.signal             # wake one waiting consumer
#       }
#     end
#
#     def pop
#       @mutex.synchronize {
#         @cv.wait(@mutex) while @queue.empty?   # sleep until item available
#         @queue.shift
#       }
#     end
#   end
#
#   q = WorkQueue.new
#
#   # 3 consumers waiting for work
#   consumers = 3.times.map { |i|
#     Thread.new {
#       item = q.pop
#       puts "Consumer #{i} got: #{item}"
#     }
#   }
#
#   # Producer pushes items
#   sleep(0.5)
#   3.times { |i| q.push("job_#{i}") }
#
#   consumers.each(&:join)
#
# -----------------------------------------------------------------------------
# 4. Example: Bounded Buffer (backpressure)
# -----------------------------------------------------------------------------
#
# Like producer-consumer, but producers ALSO block when the buffer is full.
# This prevents fast producers from overwhelming slow consumers.
#
#   class BoundedBuffer
#     def initialize(max_size)
#       @buf = []
#       @max = max_size
#       @mutex = Mutex.new
#       @not_empty = ConditionVariable.new   # consumers wait on this
#       @not_full = ConditionVariable.new    # producers wait on this
#     end
#
#     def put(item)
#       @mutex.synchronize {
#         @not_full.wait(@mutex) while @buf.size >= @max  # block if full
#         @buf << item
#         @not_empty.signal                               # wake a consumer
#       }
#     end
#
#     def take
#       @mutex.synchronize {
#         @not_empty.wait(@mutex) while @buf.empty?       # block if empty
#         item = @buf.shift
#         @not_full.signal                                # wake a producer
#         item
#       }
#     end
#   end
#
# Notice: TWO ConditionVariables, one per condition. Using a single CV for
# both conditions works but is less efficient (broadcast wakes everyone).
#
# -----------------------------------------------------------------------------
# 5. Example: Read-Write Lock
# -----------------------------------------------------------------------------
#
# Multiple threads can read simultaneously, but writing requires exclusive
# access. This is useful when reads are frequent and writes are rare.
#
#   class ReadWriteLock
#     def initialize
#       @mutex = Mutex.new
#       @cv = ConditionVariable.new
#       @readers = 0
#       @writing = false
#     end
#
#     def read_lock
#       @mutex.synchronize {
#         @cv.wait(@mutex) while @writing
#         @readers += 1
#       }
#       yield
#     ensure
#       @mutex.synchronize {
#         @readers -= 1
#         @cv.broadcast if @readers == 0    # wake waiting writers
#       }
#     end
#
#     def write_lock
#       @mutex.synchronize {
#         @cv.wait(@mutex) while @writing || @readers > 0
#         @writing = true
#       }
#       yield
#     ensure
#       @mutex.synchronize {
#         @writing = false
#         @cv.broadcast                     # wake all waiting readers/writers
#       }
#     end
#   end
#
# -----------------------------------------------------------------------------
# 6. Common Pitfalls
# -----------------------------------------------------------------------------
#
# ▸ Deadlock from nested locks
#   Methods that call each other must not each hold the mutex.
#   Solution: lock at the boundary, use unlocked helpers internally.
#
# ▸ Forgetting to signal/broadcast
#   If a thread changes state but doesn't signal, waiting threads sleep forever.
#
# ▸ Using `if` instead of `while` with cv.wait
#   Spurious wakeups can happen — always re-check the condition in a loop.
#
# ▸ Holding the mutex during slow work
#   Lock only the shared state access, not the entire operation.
#   e.g., ConnectionPool#with checks out (locked), runs block (unlocked),
#   checks in (locked).
#
# ▸ CRuby's GIL hides bugs
#   Code may appear thread-safe on CRuby but break on JRuby/TruffleRuby.
#   Any I/O (sleep, HTTP, DB) releases the GIL and exposes race conditions.
#   Always use Mutex for correctness, don't rely on the GIL.
#
# =============================================================================

class ConnectionPool
  def initialize(size, &block)
    @size = size
    @pool = []
    @mutex = Mutex.new
    @cv = ConditionVariable.new

    size.times do
      @pool << block.call
    end
  end

  def available
    @mutex.synchronize do
      @pool.count
    end
  end

  def checkout
    @mutex.synchronize do
      while _available == 0 do
        @cv.wait(@mutex)
      end
      @pool.pop
    end
  end

  def checkin(connector)
    @mutex.synchronize do
      @pool << connector
      @cv.signal
    end
  end

  def with(&block)
    connector = checkout

    begin
      block.call(connector)
    rescue => e
      puts e
    ensure
      checkin(connector)
    end
  end

  private

  def _available
    @pool.count
  end
end

# Build a thread-safe ConnectionPool that manages a fixed number of reusable connections. This is how database pools (like ActiveRecord's) work under the hood.

# Requirements:

# - ConnectionPool.new(size) { create_connection } — creates a pool of size connections using the block
# - #checkout — returns an available connection, blocks the calling thread if none are available (waits until one is returned)
# - #checkin(conn) — returns a connection back to the pool
# - #with { |conn| ... } — checks out a connection, yields it, and checks it back in automatically (even if an error is raised)
# - #available — returns the number of available connections
# - Must be thread-safe

# Example:

pool = ConnectionPool.new(2) { Object.new }

pp pool.available          # => 2

conn1 = pool.checkout
pp pool.available          # => 1

conn2 = pool.checkout
pp pool.available          # => 0

# This would block until a connection is returned:
# conn3 = pool.checkout

pool.checkin(conn1)
pp pool.available          # => 1

pool.with do |conn|
  pp pool.available        # => 0
  # use conn...
end
pp pool.available          # => 1

# Thread-safety test:
pool = ConnectionPool.new(3) { Object.new }
results = Queue.new

10.times.map {
  Thread.new {
    pool.with do |conn|
      results << conn.object_id
      sleep(0.1)
    end
  }
}.each(&:join)

# All 10 threads completed, but only 3 unique connections were used
puts results.size                              # => 10
puts results.size.times.map { results.pop }.uniq.size  # => 3

# Hint: Look into ConditionVariable for the blocking behavior — it pairs with Mutex.
