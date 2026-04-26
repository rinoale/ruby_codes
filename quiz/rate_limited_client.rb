# Scalability #1: Rate-Limited API Client
# 
# You're building a client that fetches data from an API with a rate limit: max 5 requests per second. You need to fetch 50 different resources as fast as possible without exceeding the limit.
# 
# Requirements:
# 
# - RateLimitedClient.new(max_requests_per_second:) — configurable rate limit
# - #fetch_all(urls) — fetches all URLs, returns array of results in the same order
# - Must use threads for concurrent fetching
# - Must never exceed the rate limit — no burst of 50 requests at once
# - Must be significantly faster than fetching one by one sequentially
# - Measure and print total time
# 
# Simulate the API with this:

class RateLimitedClient
  def initialize(max_requests_per_second:)
    @max_requests_per_second = max_requests_per_second
    @parallel_requests = []
    @mutex = Mutex.new
    @cv = ConditionVariable.new
  end

  def fetch_all(urls)
    result = []
    urls.each_with_index.map do |url, i|
      Thread.new do
        @mutex.synchronize do
          puts "[#{Thread.current.object_id}] waiting... (#{@parallel_requests.length} requests in window)"
          @cv.wait(@mutex, 0.1) while limited?
          puts "[#{Thread.current.object_id}] allowed at #{Time.now.strftime('%H:%M:%S.%L')}"
          @parallel_requests << Time.now
          @cv.broadcast
        end
        result[i] = fake_api_call(url)
      end
    end.each(&:join)
    result
  end

  def limited?
    @parallel_requests.reject! { |request| request < Time.now - 1 }
    @parallel_requests.length == @max_requests_per_second
  end
end

def fake_api_call(url)
  sleep(0.1)  # simulate network latency
  "Response from #{url}"
end

# Clean version using Queue as a token bucket.
# Instead of tracking timestamps and checking limits,
# pre-schedule tokens at the correct rate and let threads
# pull them. Queue handles all the blocking and thread-safety.
class RateLimitedClientClean
  def initialize(max_requests_per_second:)
    @rate = max_requests_per_second
  end

  def fetch_all(urls)
    results = Array.new(urls.length)
    token_queue = Queue.new

    # Token dispenser — feeds tokens at the allowed rate
    # Threads can't proceed without a token
    dispenser = Thread.new do
      urls.length.times do |i|
        sleep(1.0 / @rate) if i > 0  # space out evenly
        token_queue << true
      end
    end

    # Spawn all threads — each waits for a token before calling
    threads = urls.each_with_index.map do |url, i|
      Thread.new do
        token_queue.pop          # blocks until a token is available
        results[i] = fake_api_call(url)
      end
    end

    threads.each(&:join)
    dispenser.join
    results
  end
end

# Combined version: Connection Pool + Rate Limiter
# Real-world APIs have BOTH constraints:
#   - Rate limit: max N requests per second (API policy)
#   - Connection pool: max M concurrent connections (resource limit)
#
# Example: API allows 5 req/sec, but your server can only hold 3 open connections.
# You need both controls working together.
#
# This uses:
#   - Queue as connection pool (limits concurrency)
#   - Queue as token bucket (limits rate)
class RateLimitedPoolClient
  def initialize(max_requests_per_second:, max_connections: 3)
    @rate = max_requests_per_second

    # Connection pool — fixed number of "connection slots"
    @pool = Queue.new
    max_connections.times { @pool << true }
  end

  def fetch_all(urls)
    results = Array.new(urls.length)

    # Token dispenser — controls rate
    token_queue = Queue.new
    dispenser = Thread.new do
      urls.length.times do |i|
        sleep(1.0 / @rate) if i > 0
        token_queue << true
      end
    end

    threads = urls.each_with_index.map do |url, i|
      Thread.new do
        token_queue.pop        # wait for rate limit token
        @pool.pop              # wait for connection slot (blocks if all in use)
        results[i] = fake_api_call(url)
      ensure
        @pool << true          # return connection slot
      end
    end

    threads.each(&:join)
    dispenser.join
    results
  end
end

# Comparison:
#
#   RateLimitedClient        — mutex + CV, manual timestamp tracking
#   RateLimitedClientClean   — token bucket only (Queue), no concurrency limit
#   RateLimitedPoolClient    — token bucket + connection pool (two Queues)
#
#   With 5 req/sec, 3 connections, 50 urls:
#     Rate limit is the bottleneck: 50/5 = 10 seconds
#     Connection pool prevents more than 3 simultaneous API calls
#     Both constraints satisfied with just two Queues — no mutex needed

# Example:

client = RateLimitedClient.new(max_requests_per_second: 5)

urls = 50.times.map { |i| "https://api.example.com/resource/#{i}" }

results = client.fetch_all(urls)

puts results.length      # => 50
puts results.first       # => "Response from https://api.example.com/resource/0"

# Should complete in ~10 seconds (50 urls / 5 per second)
# NOT 50 * 0.1 = 5 seconds (that would mean no rate limiting)
# NOT 50 * 0.1 sequential = 50 seconds (too slow, no concurrency)

# Think about:
# - How to space out requests evenly
# - How to handle the result ordering (threads finish out of order)
# - How this relates to the ConnectionPool and RateLimiter you already built
