class RateLimiter
  def initialize(max_request, time_window)
    @max_request = max_request
    @current_request = []
    @time_window = time_window

    @mutex = Mutex.new

    # @counter = Thread.new do
    #   while true do
    #     mutex.synchronize {
    #       @current_request = 0
    #       sleep(time_window)
    #     }
    #   end
    # end
  end

  def allow?
    # Mutex#synchronize ensures only one thread executes this block at a time.
    # Without it, the sleep below causes a context switch between reading count
    # and appending — all threads see a low count and all pass through.
    # CRuby's GIL normally hides this bug, but any I/O (sleep, DB, HTTP) releases
    # the GIL and exposes the race condition.
    @mutex.synchronize do
      @current_request.filter! { |request| request > (Time.now - @time_window) }
      count_before = @current_request.length
      sleep(0.001)  # simulates I/O — forces thread context switch between read and write
      @current_request << Time.now
      count_before < @max_request
    end
  end

  # def stop_counter
  #   @counter.kill
  # end
end

#  Build a class RateLimiter that limits how many times an action can be performed within a time window. It must be thread-safe.
#
#  Requirements:
#
#  - RateLimiter.new(max_requests, time_window) — max_requests allowed per time_window seconds
#  - #allow? — returns true if the action is allowed, false if rate limit exceeded
#  - Must correctly handle concurrent access from multiple threads
#  - Old timestamps outside the window should be cleaned up (don't leak memory over time)

limiter = RateLimiter.new(3, 1.0)  # 3 requests per 1 second

pp limiter.allow?  # => true   (1st)
pp limiter.allow?  # => true   (2nd)
pp limiter.allow?  # => true   (3rd)
pp limiter.allow?  # => false  (exceeded)

sleep(1.1)

pp limiter.allow?  # => true   (window reset)

# Thread-safety test:

limiter = RateLimiter.new(5, 1.0)
results = []

1000.times.map {
  Thread.new { results << limiter.allow? }
}.each(&:join)

puts results.count(true)   # => exactly 5
puts results.count(false)
