require "concurrent"

# =============================================================================
# Concurrent::Map vs Hash - the running-jobs registry.
#
# The registry is written by WORKER threads (a job reporting that it started
# or finished) and read by PUMA threads (a dashboard request rendering it).
# That is a reader and a writer on the same object at the same time.
#
# A plain Hash does not merely risk a lost entry here; it RAISES:
#     RuntimeError: can't add a new key into hash during iteration
# in whichever thread happens to be iterating - so the dashboard request 500s
# because an unrelated background job started at the wrong moment.
# =============================================================================

TRIALS = 40

def registry_trial(store, seed_keys: 50)
  seed_keys.times { |i| store["seed#{i}"] = { "started_at" => Time.now } }

  errors = Concurrent::Array.new

  # a Puma thread rendering the dashboard
  reader = Thread.new do
    begin
      store.each { |_k, _v| Thread.pass }
    rescue => e
      errors << e.class
    end
  end

  # worker threads reporting jobs in flight
  writers = 3.times.map do |w|
    Thread.new do
      begin
        30.times { |i| store["job-#{w}-#{i}"] = { "started_at" => Time.now } }
      rescue => e
        errors << e.class
      end
    end
  end

  [reader, *writers].each(&:join)
  errors.to_a
end

puts "one reader iterating while three writers insert, #{TRIALS} trials\n\n"

hash_failures = 0
sample = nil
TRIALS.times do
  errs = registry_trial({})
  unless errs.empty?
    hash_failures += 1
    sample ||= errs.first
  end
end
puts format("  plain Hash        raised in %2d / %d trials  %s",
            hash_failures, TRIALS, sample ? "(#{sample})" : "")

map_failures = 0
TRIALS.times do
  errs = registry_trial(Concurrent::Map.new)
  map_failures += 1 unless errs.empty?
end
puts format("  Concurrent::Map   raised in %2d / %d trials", map_failures, TRIALS)
puts

# --- what the read side actually does --------------------------------------
# AsyncQueue#running takes .values, i.e. a SNAPSHOT, then sorts and decorates
# it outside the map. Snapshotting first keeps the iteration short and means
# the render never holds the structure open while jobs come and go.
registry = Concurrent::Map.new
registry["a"] = { "started_at" => Time.now - 3 }
registry["b"] = { "started_at" => Time.now - 1 }

writer = Thread.new { 200.times { |i| registry["churn#{i}"] = { "started_at" => Time.now } } }
snapshot = registry.values                        # detached copy, safe to sort
writer.join

puts "snapshot taken mid-churn: #{snapshot.size} entries (map now holds #{registry.size})"
puts "the snapshot is a plain Array - sort it, map it, render it, all off-lock."
puts

# =============================================================================
# Caveat that bites in dev: Concurrent::Map is thread-safe, not durable. The
# registry is a class-level ivar, so a code reload builds a NEW class with a
# NEW empty map and in-flight rows vanish from the dashboard. Cosmetic, and
# dev-only - but it looks like a bug the first time you hit it.
# =============================================================================
