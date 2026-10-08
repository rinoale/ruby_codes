require "concurrent"

# =============================================================================
# The design difference that makes cancel / reorder possible.
#
# STOCK:  executor.post { run(job) }
#         The job is now inside the executor's private queue. There is no API
#         to reach in and remove or move it. It is gone until it runs.
#
# TOKENS: backlog << job_data ; executor.post { run_next }
#         The pool holds anonymous "run the next one" tokens; YOU hold the
#         ordered job list under a mutex. Tokens never name a job, so:
#           - N tokens still drain N jobs in FIFO order
#           - a cancelled job leaves a surplus token that harmlessly no-ops
#           - reordering the backlog reorders execution
# =============================================================================

# --- A. direct post: uncancellable ----------------------------------------
puts "A. executor.post { run(job) }"
ran = Concurrent::Array.new
cancelled = Concurrent::Array.new
gate = Concurrent::CountDownLatch.new(1)

pool = Concurrent::ThreadPoolExecutor.new(min_threads: 0, max_threads: 1, max_queue: 0)
pool.post { gate.wait(5) }                       # occupy the single worker
%w[J1 J2 J3 J4 J5].each do |id|
  pool.post do
    # The ONLY lever left: the job interrogates a shared set itself.
    next if cancelled.include?(id)
    ran << id
  end
end

cancelled << "J3"                                 # "cancel" J3
# There is no pool.reorder / pool.delete to call here. That is the point.
gate.count_down
pool.shutdown
pool.wait_for_termination

puts "    ran: #{ran.to_a.inspect}"
puts "    J3 skipped, but only because the job checked a flag; it still"
puts "    occupied a worker turn, and nothing could be reordered."
puts

# --- B. backlog + tokens: cancellable and reorderable ----------------------
puts "B. backlog << data ; executor.post { run_next }"

class MiniLane
  attr_reader :ran, :noop_tokens

  def initialize(max_workers: 1)
    @backlog = []
    @mutex = Mutex.new
    @ran = Concurrent::Array.new
    @noop_tokens = Concurrent::AtomicFixnum.new
    @executor = Concurrent::ThreadPoolExecutor.new(
      min_threads: 0, max_threads: max_workers, max_queue: 0
    )
  end

  def push(job_data)
    @mutex.synchronize { @backlog << job_data }
    @executor.post { run_next }                   # <- an interchangeable token
  end

  def delete(job_id)
    @mutex.synchronize do
      index = @backlog.index { |d| d["job_id"] == job_id }
      @backlog.delete_at(index) if index
    end
  end

  def reorder(job_id, before:)
    @mutex.synchronize do
      index = @backlog.index { |d| d["job_id"] == job_id }
      anchor = @backlog.index { |d| d["job_id"] == before }
      return unless index && anchor

      data = @backlog.delete_at(index)
      anchor -= 1 if anchor > index
      @backlog.insert(anchor, data)
      data
    end
  end

  def pending
    @mutex.synchronize { @backlog.map { |d| d["job_id"] } }
  end

  def drain
    @executor.shutdown
    @executor.wait_for_termination
  end

  private

  def run_next
    data = @mutex.synchronize { @backlog.shift }
    return @noop_tokens.increment unless data      # surplus token, nothing to do

    data["gate"]&.wait(5)
    @ran << data["job_id"]
  end
end

lane = MiniLane.new(max_workers: 1)
gate = Concurrent::CountDownLatch.new(1)
lane.push("job_id" => "gate", "gate" => gate)      # hold the worker still
%w[J1 J2 J3 J4 J5].each { |id| lane.push("job_id" => id) }

puts "    backlog:           #{lane.pending.inspect}"
puts "    cancel J3       -> #{lane.delete('J3') ? 'removed' : 'too late'}"
puts "    move J5 before J1"
lane.reorder("J5", before: "J1")
puts "    backlog now:       #{lane.pending.inspect}"

gate.count_down
lane.drain

puts "    ran: #{lane.ran.to_a.inspect}"
puts "    surplus tokens that found nothing: #{lane.noop_tokens.value}"
puts
puts "J3 never ran at all. J5 jumped the line. 6 pushes -> 6 tokens ->"
puts "5 jobs executed + 1 no-op, so the counts never drift."
puts
puts "Caveat both ways: once a worker has SHIFTED a job, it is unreachable"
puts "again - that is why cancel returns nil for a running job."
