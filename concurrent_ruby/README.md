# concurrent-ruby, by way of a per-queue ActiveJob adapter

Runnable comparisons for the concurrency primitives behind a custom ActiveJob
adapter that gives every named queue its own worker pool (and can therefore
cancel, reorder and move jobs that are still waiting).

Each script is standalone and prints a bad-vs-good contrast:

```sh
ruby 01_atomic_vs_plain_counter.rb
```

No Gemfile needed — concurrent-ruby ships with Rails and is already installed.

| # | File | Contrast | Why the adapter cares |
|---|------|----------|----------------------|
| 01 | `01_atomic_vs_plain_counter.rb` | `+=` vs `Mutex` vs `AtomicFixnum` | `@completed` is one number touched by one op, so CAS beats a lock — and keeps the counter off the backlog mutex |
| 02 | `02_array_vs_guarded_backlog.rb` | raw `Array` vs mutex-guarded | `delete`/`reorder` are check-then-act (`index` then `delete_at`); unguarded, they cancel the *wrong job* |
| 03 | `03_thread_pool_lanes.rb` | one shared pool vs a pool per queue | the stock `AsyncAdapter` ignores `queue_name`; per-queue pools are what make `max_workers: 1` mean anything |
| 04 | `04_token_indirection.rb` | `post { run(job) }` vs `backlog` + anonymous tokens | the design that makes a waiting job cancellable and movable at all |
| 05 | `05_scheduled_task.rb` | `ScheduledTask` vs `Thread.new { sleep }` | delayed jobs cost a timer, not a parked thread — and the timer must *push*, not run |
| 06 | `06_map_vs_hash.rb` | `Hash` vs `Concurrent::Map` | worker threads write the running-jobs registry while a web thread renders it |

## The one to read first

`04_token_indirection.rb`. Everything else is a standard concurrency lesson;
that one is the actual design decision.

Rails' `AsyncAdapter` posts the job straight into the executor:

```ruby
executor.post(job, &:perform)     # job is now unreachable
```

Once posted, the job lives in the pool's private queue. Nothing can remove it,
delay it, or move it ahead of another. The alternative keeps the ordered job
list yourself and posts an interchangeable token per job:

```ruby
@mutex.synchronize { @backlog << job_data }
@executor.post { run_next }       # "run whatever is at the head"
```

Because tokens never name a job:

- N tokens still drain N jobs, FIFO, per queue
- cancelling a waiting job leaves a surplus token that finds an empty head and
  harmlessly no-ops
- reordering the backlog reorders execution, with no pool API involved

The cost is that the backlog is now shared mutable state — which is exactly
why 01 and 02 matter.

## What none of this survives

In-process and per-process, on purpose:

- a restart drops every backlog — nothing is persisted
- a `rails console`, or a second Puma worker, sees its own empty queues
- a job already **shifted** by a worker cannot be cancelled; running work runs
  to completion
- a code reload replaces the running-jobs registry with an empty one (dev only,
  cosmetic)

## Where the thread-safety lines actually fall

| State | Guard | Touched by |
|-------|-------|-----------|
| `@backlog` | `Mutex` | web threads (push/cancel/reorder) + workers (shift) |
| `@completed` | `AtomicFixnum` | workers only, but read by web threads |
| running registry | `Concurrent::Map` | workers write, web threads read |
| the pool itself | concurrent-ruby | — |
