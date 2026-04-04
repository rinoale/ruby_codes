# prepended(base) — fires when a module is prepended
# prepend inserts BEFORE the class in lookup chain, so `super` calls the original

module Timing
  def self.prepended(base)
    puts "[prepended] #{self} prepended to #{base}"
  end

  def slow_work
    start = Time.now
    result = super  # calls the original App#slow_work
    elapsed = Time.now - start
    puts "[Timing] slow_work took #{elapsed.round(3)}s"
    result
  end
end

class App
  def slow_work
    sleep(0.2)
    "done"
  end
end

# Without prepend — no timing
puts App.new.slow_work
puts "---"

# Now prepend — wraps the method
App.prepend(Timing)
puts App.new.slow_work

# Method lookup: Timing#slow_work → App#slow_work
puts "Ancestors: #{App.ancestors.inspect}"
