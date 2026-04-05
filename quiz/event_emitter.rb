# Advanced #10: Event Emitter
# 
# Build a class EventEmitter that implements the observer pattern — objects can subscribe to named events and get notified when those events fire.
# 
# Requirements:
# 
# - #on(event, &block) — register a listener for an event. Multiple listeners per event allowed. Returns a listener ID for later removal.
# - #emit(event, *args) — fire an event, calling all registered listeners with the given arguments, in the order they were registered
# - #off(event, listener_id) — remove a specific listener
# - #once(event, &block) — register a listener that auto-removes after firing once
# - #listener_count(event) — return the number of listeners for an event
# 
# Example:

# Review:
# - Using block.object_id as listener ID is clever — avoids a manual counter.
# - Storing { block:, once: } per listener keeps the data model flat and simple.
# - Deleting during iteration (line 31) works in Ruby since Hash#each iterates
#   over a snapshot, but worth noting it's implementation-dependent behavior.
class EventEmitter
  def initialize
    @event_map = {}
  end

  def on(event_name, &block)
    @event_map[event_name] ||= {}
    @event_map[event_name][block.object_id] = { block: }
    block.object_id
  end

  def emit(event_name, *args)
    return if @event_map[event_name].nil?

    @event_map[event_name].each do |ei, config|
      config[:block].call(*args)
      @event_map[event_name].delete(ei) if config[:once]
    end
    @event_map.delete(event_name) if @event_map[event_name][:once]
  end

  def listener_count(event_name)
    @event_map[event_name]&.values&.count || 0
  end

  def off(event_name, event_id)
    @event_map[event_name].delete(event_id)
  end

  def once(event_name, &block)
    event_id = on(event_name, &block)
    @event_map[event_name][event_id][:once] = true
    event_id
  end
end

emitter = EventEmitter.new

# Register listeners
id1 = emitter.on(:data) { |msg| puts "Listener 1: #{msg}" }
id2 = emitter.on(:data) { |msg| puts "Listener 2: #{msg}" }

emitter.emit(:data, "hello")
# => Listener 1: hello
# => Listener 2: hello

emitter.listener_count(:data)  # => 2

# Remove one listener
emitter.off(:data, id1)
emitter.emit(:data, "world")
# => Listener 2: world

emitter.listener_count(:data)  # => 1

# Once — fires only once
emitter.once(:done) { |code| puts "Exit: #{code}" }
emitter.emit(:done, 0)   # => Exit: 0
emitter.emit(:done, 0)   # (nothing — already removed)
emitter.listener_count(:done)  # => 0

emitter.on(:done) { |code| puts "Permanent: #{code}" }
emitter.once(:done) { |code| puts "One-time: #{code}" }
emitter.emit(:done, 0)
# => Permanent: 0
# => One-time: 0
emitter.emit(:done, 0)
# => Permanent: 0  (still here)
# one-time listener is gone
