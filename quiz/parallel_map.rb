# Scalability #2: Parallel Map with Worker Pool
# 
# Build a parallel_map method that works like Array#map but processes elements concurrently using a fixed number of worker threads — not one thread per element.
# 
# Why fixed workers matter: Spawning 10,000 threads for 10,000 items wastes resources. Real systems (Sidekiq, Puma, database pools) use a fixed worker pool.
# 
# Requirements:
# 
# - parallel_map(array, workers:) { |element| ... } — returns results in the same order as input
# - workers: — number of worker threads (fixed, not one per element)
# - Workers pull tasks from a shared queue until all work is done
# - Must be thread-safe
# - Must be faster than sequential map when the block involves I/O
# 
# Example:

def parallel_map(arr, workers:, &block)
  queue = Queue.new
  worker_pool = []
  result = []

  workers.times do |i|
    worker_pool << Thread.new do
      while (task = queue.pop) do
        puts "[#{Thread.current.object_id}] processing"
        task.call
      end
    end
  end

  arr.each_with_index.map do |e, i|
    queue << Proc.new do
      result[i] = block.call(e)
    end
  end
  # 3. Poison pills — tell workers to stop
  workers.times { queue << nil }
  worker_pool.each(&:join)
  result
end

# Sequential: 10 × 0.5s = 5 seconds
results = (1..10).map { |i| sleep(0.5); i * 2 }

# Parallel with 3 workers: ~2 seconds (ceil(10/3) × 0.5s)
results = parallel_map((1..10).to_a, workers: 3) { |i| sleep(0.5); i * 2 }
puts results
# => [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]  (same order as input)

# Proving it's faster
start = Time.now
pp parallel_map((1..20).to_a, workers: 5) { |i| sleep(0.2); i }
puts "Time: #{(Time.now - start).round(1)}s"
# => ~0.8s (ceil(20/5) × 0.2s), not 4s sequential

# Think about:
# - How workers know which element to process next
# - How to preserve result order when workers finish out of order
# - How workers know when to stop (no more work left)
# - What you just learned about Queue
