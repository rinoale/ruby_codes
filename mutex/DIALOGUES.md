# Mutex & ConditionVariable — Learning Dialogues

## 01_race_condition.rb

**What happens step by step:**

The goal: 100 threads each increment `counter` by 1. Expected result: 100.

The problem: Incrementing is actually 3 steps, not 1:

```
1. READ   — current = counter  (read the value)
2. MODIFY — current + 1        (compute new value)
3. WRITE  — counter = current + 1  (write it back)
```

Without protection, threads interleave between these steps:

```
Time    Thread A              Thread B              counter
────    ────────              ────────              ───────
 1      current = counter                              0
        (reads 0)
 2                            current = counter        0
                              (also reads 0!)
 3      counter = 0 + 1                                1
 4                            counter = 0 + 1          1  ← should be 2!
```

Both threads read 0, both write 1. One increment is lost.

The `sleep(delay)` simulates real-world I/O (database queries, HTTP calls) that releases Ruby's GIL and lets other threads run between the read and write.

---

### Q: GIL is global interpreter lock, right?

Yes. GIL (Global Interpreter Lock) means CRuby only runs **one thread's Ruby code at a time**, even on multi-core CPUs.

But there's an important exception: **I/O operations release the GIL**. When a thread hits `sleep`, reads a file, makes an HTTP request, or queries a database — the GIL is released and another thread can run Ruby code.

That's why `sleep(delay)` in the example exposes the bug. Without it, `current = counter` and `counter = current + 1` execute so fast that no other thread gets a chance to interleave. With `sleep`, the GIL releases, another thread jumps in, reads the same stale value, and the race condition happens.

In production, you don't need artificial `sleep` — real I/O does the same thing naturally.

---

## 02_mutex_fix.rb

Same code as before, but now the read-modify-write is wrapped in `mutex.synchronize`.

Here's what changes:

```
Time    Thread A                    Thread B              counter
────    ────────                    ────────              ───────
 1      mutex.synchronize {         mutex.synchronize {      0
        (acquires lock ✓)           (BLOCKED — waiting)
 2      current = counter                                    0
        (reads 0)
 3      sleep — GIL releases                                 0
        (Thread B wakes up but
         can't enter — mutex
         is still locked by A)
 4      counter = 0 + 1                                      1
        } (releases lock)
 5                                  (acquires lock ✓)        1
 6                                  current = counter        1
                                    (reads 1 — correct!)
 7                                  counter = 1 + 1          2
                                    } (releases lock)
```

The key: even though `sleep` releases the GIL and lets Thread B's Ruby code run, Thread B hits `mutex.synchronize` and **blocks** because Thread A still holds the lock. Thread B can't enter the critical section until Thread A finishes and releases.

So the interleaving that caused the bug in `01` is now impossible. Every thread sees the latest value.

**Trade-off:** safety costs speed. In `01`, all 100 threads run concurrently (fast but wrong). In `02`, they run one at a time through the critical section (slow but correct).

---

## 03_deadlock.rb

This is what happens when two threads lock two mutexes in **opposite order**:

```
Time    Thread 1                  Thread 2
────    ────────                  ────────
 1      locks mutex_a ✓
 2                                locks mutex_b ✓
 3      wants mutex_b...          wants mutex_a...
        (B is held by T2)         (A is held by T1)
        BLOCKED                   BLOCKED
        ↓                         ↓
        waiting for T2            waiting for T1
        which waits for T1        which waits for T2
        ∞                         ∞
```

Neither thread can proceed. Both are waiting for the other to release. This is a **circular dependency** — and it lasts forever.

**The fix is simple:** always acquire multiple locks in the **same order**. If both threads lock A then B, no circular dependency, no deadlock.

---

### Q: So, basic condition for deadlock is, at least there are 2 mutex, huh?

Exactly for the classic deadlock — two mutexes, two threads, opposite locking order.

But you can also deadlock with **one mutex** — a thread locks a mutex, then calls a method that tries to lock the **same** mutex again. The thread blocks waiting for itself to release:

```
Thread A:
  mutex.synchronize {        ← locked
    mutex.synchronize {      ← blocked, waiting for... itself
    }
  }
```

Ruby raises `ThreadError: deadlock; recursive locking` for this case.

So the two forms are:
- **2 mutexes, 2 threads** — circular dependency (waits forever silently)
- **1 mutex, 1 thread** — recursive locking (Ruby catches it immediately)

---

### Q: What is the pause before DEADLOCK message?

That's the `t.join(2)` — it waits **up to 2 seconds** for each thread to finish. When a thread is deadlocked, it never finishes, so `join` times out after 2 seconds and returns `nil`.

Without the timeout (`t.join` with no argument), the main thread would wait forever too — the whole program would hang.

---

### Q: Can ruby detect deadlock naturally?

Yes, but only in specific cases:

**Ruby detects automatically:**
- **Recursive locking** — same thread tries to lock the same Mutex twice. Raises `ThreadError: deadlock; recursive locking` immediately.
- **All threads sleeping** — if every thread in the program is blocked and nothing can wake them, Ruby raises `fatal: No live threads left. Deadlock?`

**Ruby does NOT detect:**
- **The classic two-mutex deadlock** — because the threads aren't dead, they're "alive" and waiting. Ruby can't tell they'll wait forever. That's why we needed `join(2)` with a timeout to catch it ourselves.

---

## 04_producer_consumer.rb

This is where `ConditionVariable` shines. The problem: consumers need to wait for items, but **how** should they wait?

**Bad approach — busy-waiting (polling):**
```ruby
def pop
  mutex.synchronize {
    sleep(0.1) while @queue.empty?  # wastes CPU, holds the lock!
  }
end
```
This is terrible — the thread holds the mutex while sleeping, so the producer can never push.

**Good approach — ConditionVariable:**
```ruby
def pop
  mutex.synchronize {
    @cv.wait(@mutex) while @queue.empty?
    @queue.shift
  }
end
```

`@cv.wait(@mutex)` does three things atomically:
1. **Releases** the mutex (so the producer can push)
2. **Sleeps** the thread (no CPU wasted)
3. **Re-acquires** the mutex when woken up

Then on the producer side, `@cv.signal` wakes one sleeping consumer.

Timeline:

```
Time    Consumer 0          Consumer 1          Producer
────    ──────────          ──────────          ────────
 1      pop → lock mutex
        queue empty?  yes
        cv.wait → release
        mutex, sleep
 2                          pop → lock mutex
                            queue empty? yes
                            cv.wait → sleep
 3                                              push("job_a") → lock mutex
                                                queue << "job_a"
                                                cv.signal → wakes Consumer 0
 4      (wakes up)
        re-acquires mutex
        queue empty? no
        queue.shift → "job_a"
```

The key insight: `wait` **releases the lock while sleeping**. Without this, the producer could never acquire the mutex to push items — and you'd be deadlocked.

---

### Q: So, one mutex, one cv is sort of pair, right? cv needs mutex, correct?

Correct. A CV is useless without a Mutex — `cv.wait(mutex)` **requires** a mutex as its argument because it needs to release something while sleeping and re-acquire it on wakeup.

But a Mutex works fine alone when you just need exclusive access. You only add a CV when threads need to **wait for a condition to change**.

Summary:
- **Mutex alone** — "only one thread at a time" (locking)
- **Mutex + CV** — "only one thread at a time, AND wait until something happens" (locking + signaling)

And you can pair **one Mutex with multiple CVs** when you have multiple conditions to wait on (see `05`).

---

### Q: Mutex is not just locking certain object but locking certain session?

A perfect analogy using a flag:

- **Flag** = Mutex
- **Trying to hold the flag** = `synchronize` (attempting to acquire)
- **Holding the flag** = inside the `synchronize` block (lock acquired)
- **Waiting for the flag** = blocked at `synchronize` (lock held by someone else)
- `cv.wait(mutex)` — you put the flag down, sit quietly, and wait for someone to tap your shoulder
- `cv.signal` — you tap one person's shoulder so they can grab the flag next
- `cv.broadcast` — you tap everyone's shoulder

The flag doesn't protect a specific object — it protects the **conversation** (critical section). Anyone holding it can talk about anything. That's why one Mutex can protect multiple variables at once.

---

### Q: What is the definition of mutex?

Mutex = **mut**ual **ex**clusion. It's a computer science term, coined for concurrent programming. No outside origin like "thread" (which comes from weaving).

The concept: if two things are **mutually exclusive**, only one can happen at a time. A mutex enforces that rule in code.

The term has been around since the 1960s, from early OS research by Dijkstra (who also gave us the semaphore, another concurrency primitive).

---

### Q: What is different between broadcast and signal?

- `signal` — wakes **one** waiting thread
- `broadcast` — wakes **all** waiting threads

Use `signal` when only one thread can proceed (e.g., one item added to a queue → one consumer can take it).

Use `broadcast` when the condition change affects everyone (e.g., a writer finishes → all readers can proceed).

---

### Q: So, solving connection pool with sleep loop was the brutal way, cv is more elegant?

Exactly. The original approach:

```ruby
while available == 0 do
  sleep(1)  # poll every second
end
```

This is busy-waiting — wastes time sleeping a fixed interval. If a connection returns after 0.01s, you still wait up to 1s.

With CV:

```ruby
@cv.wait(@mutex) while @pool.empty?
```

The thread wakes up **instantly** when `checkin` calls `@cv.signal`. Zero wasted time, zero CPU burned on polling.

It's the difference between refreshing a webpage every 5 seconds vs. receiving a push notification.

---

### Q: What is the order of receiving released mutex? First wait, first receive?

No — the order is **not guaranteed**. Ruby's thread scheduler decides which waiting thread gets the mutex next, and it's essentially unpredictable.

With `cv.signal`, only **one** thread wakes up, but you can't control which one. With `cv.broadcast`, **all** wake up, but they re-acquire the mutex one at a time in an arbitrary order.

If you need strict ordering (FIFO), you'd have to build it yourself — for example, using a queue of per-thread condition variables.

---

## 05_bounded_buffer.rb

In `04`, only consumers waited. But what if the producer is **much faster** than the consumer? Without a limit, the buffer grows forever and eats all memory.

`BoundedBuffer` solves this with **two conditions**:
- Consumer: "I can't take — buffer is **empty**" → wait on `@not_empty`
- Producer: "I can't put — buffer is **full**" → wait on `@not_full`

Each side signals the other when it changes the condition:

```
Time    Producer (fast)              Consumer (slow)         Buffer
────    ──────────────               ──────────────          ──────
 1      put item_0                                          [0] 1/3
 2      put item_1                                          [0,1] 2/3
 3      put item_2                                          [0,1,2] 3/3
 4      put item_3 → FULL!
        @not_full.wait (sleeps)
 5                                   take item_0            [1,2] 2/3
                                     @not_full.signal
 6      (wakes up!)
        put item_3                                          [1,2,3] 3/3
        put item_4 → FULL!
        @not_full.wait (sleeps)
 7                                   take item_1            [2,3] 2/3
                                     @not_full.signal
 ...    (continues this dance)
```

The producer is forced to slow down to the consumer's pace. The buffer never exceeds 3 items. This is **backpressure**.

Real-world uses:
- HTTP server with a request queue (don't accept unlimited requests)
- Log writer buffering to disk (don't buffer unlimited logs in memory)
- LazyCSV was solving a similar problem — don't load unlimited rows

Notice: one Mutex, two CVs. The Mutex protects the shared buffer. Each CV tracks a separate condition.

---

## 06_read_write_lock.rb

With a regular Mutex, readers block each other even though reading is safe to do concurrently. That's wasteful when reads are frequent and writes are rare.

A Read-Write Lock has two rules:
- **Readers** — unlimited at the same time, but not while someone is writing
- **Writers** — only one, and no readers allowed during the write

```
Scenario                  Allowed?
────────                  ────────
Reader + Reader           ✓  (concurrent reads are safe)
Reader + Writer           ✗  (writer might change data mid-read)
Writer + Writer           ✗  (two writes would corrupt data)
```

The key difference between `read_lock` and `write_lock`:

```ruby
# read_lock waits only for writers
@cv.wait(@mutex) while @writing

# write_lock waits for BOTH writers AND readers
@cv.wait(@mutex) while @writing || @readers > 0
```

Both methods **release the mutex before yielding** — lock to change state, unlock for the actual work, lock again to clean up. Same pattern as `ConnectionPool#with`.

`write_lock` uses `broadcast` (not `signal`) in `ensure`. When a writer finishes, **all** waiting readers can proceed simultaneously.

---

### Q: So, both read_lock and write_lock exist only for write to protect ACID?

Close but slightly different. ACID is a database concept (Atomicity, Consistency, Isolation, Durability). Read-Write Lock only covers the **Isolation** part — making sure reads don't see half-written data.

But the core idea is right: the lock exists **because of writes**. If nobody ever wrote, you'd need no lock at all — concurrent reads of unchanged data are always safe.

---

## 07_signal_vs_broadcast.rb

A direct comparison.

**`signal`**: 3 threads waiting, only 1 wakes up. The other 2 stay asleep forever.

```
cv.signal

Thread 0: 💤 → 😀 woke up!
Thread 1: 💤 → 💤 still sleeping
Thread 2: 💤 → 💤 still sleeping
```

**`broadcast`**: 3 threads waiting, all 3 wake up. They re-acquire the mutex one at a time.

```
cv.broadcast

Thread 0: 💤 → 😀 woke up!
Thread 1: 💤 → 😀 woke up!
Thread 2: 💤 → 😀 woke up!
```

When to use which:

| Pattern | Use | Why |
|---------|-----|-----|
| Producer-Consumer (`04`) | `signal` | One item added → one consumer can take it |
| Bounded Buffer (`05`) | `signal` | One slot freed → one producer can put |
| Read-Write Lock (`06`) | `broadcast` | Writer done → all readers can proceed |
| Connection Pool (quiz) | `signal` | One connection returned → one thread can check out |

The rule: **can only one thread benefit from the change?** Use `signal`. **Can multiple threads benefit?** Use `broadcast`.

Using `broadcast` where `signal` suffices works but wastes effort — all threads wake up, re-check the condition, and all but one go back to sleep. Using `signal` where `broadcast` is needed is a bug — threads that should proceed stay asleep.

---

### Q: broadcast still needs to wait for mutex release, right?

Right. `broadcast` wakes all threads, but they still re-acquire the mutex **one at a time**:

```
Before broadcast:
  Thread 0: sleeping on cv.wait
  Thread 1: sleeping on cv.wait
  Thread 2: sleeping on cv.wait

After broadcast:
  Thread 0: waiting for mutex    → gets it first  → runs → releases
  Thread 1: waiting for mutex    → gets it second → runs → releases
  Thread 2: waiting for mutex    → gets it third  → runs → releases
```

The difference from `signal` is that all three are **awake and queued** for the mutex, instead of two still sleeping. They'll all get their turn — just not simultaneously.

That's also why the `while` loop matters. After `broadcast`, Thread 0 might change the condition. When Thread 1 finally gets the mutex, it re-checks and might go back to sleep if the condition no longer holds.
