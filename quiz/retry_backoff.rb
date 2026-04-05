#  Ruby Quiz — Advanced #11: Retry with Exponential Backoff
#
#  Build a method with_retry that retries a block on failure with configurable backoff strategy. This is a common pattern for unreliable network calls.
#
#  Requirements:
#
#  - with_retry(max_attempts:, base_delay:, max_delay:, exceptions:) — takes a block and retries on failure
#  - max_attempts: — total number of tries (including the first)
#  - base_delay: — initial delay in seconds before first retry
#  - max_delay: — delay cap in seconds (backoff never exceeds this)
#  - exceptions: — array of exception classes to catch. Any other exception should not be caught.
#  - Delay doubles each retry (exponential): base_delay, base_delay * 2, base_delay * 4, ...
#  - Delay never exceeds max_delay
#  - If all attempts fail, raise the last exception
#  - Returns the block's return value on success
#  - Prints which attempt it's on and the delay before each retry
#
#  Example:

# Review:
# - Recursive approach is clean and avoids manual loop state.
# - Exposing current_try as a keyword arg works, but it leaks an internal detail
#   to the caller — they could call with_retry(current_try: 99). A wrapper method
#   or inner method would hide it.
# - Ruby has a built-in `retry` keyword inside rescue blocks that re-runs the
#   begin block — could replace the recursion with a loop + retry.
def with_retry(max_attempts:, base_delay:, max_delay:, exceptions:, current_try: 1, &block)
  begin
    block.call
  rescue => e
    raise e if exceptions.none? { |exception_class| e.is_a? exception_class  }
    raise e if current_try == max_attempts

    retry_time = base_delay * (2 ** (current_try - 1))
    puts "Attempt #{current_try} failed: Connection failed. Retrying in #{retry_time}s..."
    sleep([retry_time, max_delay].min)
    with_retry(max_attempts:, base_delay:, max_delay:, exceptions:, current_try: current_try + 1, &block)
  end
end

attempt = 0

result = with_retry(max_attempts: 4, base_delay: 0.1, max_delay: 1.0, exceptions: [RuntimeError]) do
  attempt += 1
  raise "Connection failed" if attempt < 3
  "Connected!"
end
# => Attempt 1 failed: Connection failed. Retrying in 0.1s...
# => Attempt 2 failed: Connection failed. Retrying in 0.2s...
# => Attempt 3 succeeded!
puts result  # => "Connected!"

# Uncaught exception type — should NOT retry
begin
  with_retry(max_attempts: 3, base_delay: 0.1, max_delay: 1.0, exceptions: [RuntimeError]) do
    raise ArgumentError, "bad input"
  end
rescue ArgumentError => e
  puts "Not retried: #{e.message}"
end
# => Not retried: bad input
