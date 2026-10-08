# =============================================================================
# Three ways to index a list you keep mutating: scan, position map, node map.
#
# The shape: an ordered list whose entries are removed by *identity* rather
# than position, while the head is popped constantly. Locating the entry is
# the whole problem, and the choice of index decides whether it helps or
# quietly rots:
#
#     Array         index { |e| e == id }   O(N) find, then O(N) splice
#     id => index   O(1) find ... until the next shift renumbers everything
#     id => node    O(1) find, O(1) splice, nothing to renumber
#
# The middle one is the trap. A map is only as trustworthy as the thing it
# stores, and a position is not stable: popping the head moves every entry
# behind it down by one, so the map now points one to the left and a delete
# removes the WRONG ENTRY. Keeping it honest means rebuilding the map on every
# pop — O(N) on the hottest path, strictly worse than the scan it replaced.
# Only the node map wins both, by never storing a position to begin with.
#
# Same two-indexes-over-one-collection idea as sorted_set.rb, with a linked
# list standing in for the skip list: a hash for identity, links for order.
#
# Modelled on a job backlog (a worker pops the head; a cancel removes by
# job_id). Deliberately single-threaded — the locking side of that same
# backlog is concurrent_ruby/02_array_vs_guarded_backlog.rb.
# =============================================================================

JOBS = ("A".."J").to_a

# --- 1. plain Array: correct, scans ------------------------------------------
class ArrayBacklog
  def initialize = @backlog = []
  def to_a = @backlog.dup

  def push(id) = @backlog << id
  def shift = @backlog.shift

  def delete(id)
    index = @backlog.index(id)
    @backlog.delete_at(index) if index
  end

  def move_before(id, anchor_id)
    index = @backlog.index(id)
    return unless index && @backlog.index(anchor_id)

    @backlog.delete_at(index)
    @backlog.insert(@backlog.index(anchor_id), id)
  end
end

# --- 2. id => index: O(1) lookup onto a position that keeps moving -----------
class IndexMapBacklog
  def initialize
    @backlog = []
    @at = {}
  end
  def to_a = @backlog.dup

  def push(id)
    @at[id] = @backlog.size
    @backlog << id
  end

  # A worker takes the head. Every surviving index is now off by one, and
  # nothing here fixes that — see IndexMapRebuildBacklog for the price of
  # fixing it.
  def shift
    id = @backlog.shift
    @at.delete(id)
    id
  end

  def delete(id)
    index = @at.delete(id)
    @backlog.delete_at(index) if index
  end

  def move_before(id, anchor_id)
    index, anchor = @at[id], @at[anchor_id]
    return unless index && anchor

    @backlog.insert(anchor, @backlog.delete_at(index))
  end
end

# --- 2b. the same, kept correct: rebuild the map on every shift --------------
class IndexMapRebuildBacklog < IndexMapBacklog
  def shift
    id = super
    reindex
    id
  end

  def delete(id)
    removed = super
    reindex if removed
    removed
  end

  private

  def reindex
    @at = {}
    @backlog.each_with_index { |job, i| @at[job] = i }
  end
end

# --- 3. id => node: order in the links, lookup in the map -------------------
class LinkedMapBacklog
  Node = Struct.new(:id, :prev, :next)

  def initialize
    @head = nil
    @tail = nil
    @index = {}
  end

  def size = @index.size
  def push(id) = link(Node.new(id), after: @tail)
  def shift = unlink(@head)&.id
  def delete(id) = unlink(@index[id])&.id

  def move_before(id, anchor_id)
    node, anchor = @index[id], @index[anchor_id]
    return if node.nil? || anchor.nil? || node == anchor

    after = anchor.prev
    unlink(node)
    # Moving onto the very next neighbour makes `after` the node itself,
    # which is no longer linked — step back one.
    link(node, after: after == node ? node.prev : after)
    node.id
  end

  def to_a
    node = @head
    Array.new(size) { id = node.id; node = node.next; id }
  end

  private

  def link(node, after:)
    node.prev = after
    node.next = after ? after.next : @head
    node.prev ? node.prev.next = node : @head = node
    node.next ? node.next.prev = node : @tail = node
    @index[node.id] = node
    node.id
  end

  def unlink(node)
    return unless node

    node.prev ? node.prev.next = node.next : @head = node.next
    node.next ? node.next.prev = node.prev : @tail = node.prev
    @index.delete(node.id)
    node
  end
end

BACKLOGS = { "Array" => ArrayBacklog,
             "id => index" => IndexMapBacklog,
             "id => index +rebuild" => IndexMapRebuildBacklog,
             "id => node" => LinkedMapBacklog }.freeze

def filled(klass, ids = JOBS)
  klass.new.tap { |backlog| ids.each { |id| backlog.push(id) } }
end

# --- does it still remove the right entry? ----------------------------------
# Strictly sequential: pop, then delete. There is no race to lose here — the
# position map is simply wrong about where things are by the time it is asked.
puts "backlog #{JOBS.inspect}"
puts "pop the head (A), then cancel E\n\n"

BACKLOGS.each do |label, klass|
  backlog = filled(klass)
  backlog.shift
  backlog.delete("E")
  left = backlog.to_a
  verdict = left == JOBS - %w[A E] ? "ok" : "WRONG — cancelled #{(JOBS - %w[A] - left).join(', ')}"
  puts format("  %-21s %-32s %s", label, left.join(""), verdict)
end

# --- and what does the lookup actually cost? --------------------------------
require "benchmark"

N = 100_000
ROUNDS = 200
ids = Array.new(N) { |i| "job-#{i}" }
# Cancel from deep in the backlog, where a scan has to walk to find it.
targets = Array.new(ROUNDS) { |i| "job-#{N - 1 - i}" }

puts "\n#{N} waiting jobs; #{ROUNDS} x (pop the head + cancel a job near the tail)\n\n"

BACKLOGS.each do |label, klass|
  backlog = filled(klass, ids)
  elapsed = Benchmark.realtime do
    targets.each do |target|
      backlog.shift
      backlog.delete(target)
    end
  end
  left = backlog.to_a
  # Size alone is not enough: a stale index still deletes *a* job, just not
  # the one asked for. The cancelled ids have to be the ones actually gone.
  intact = left.size == N - (ROUNDS * 2) && (left & targets).empty?
  puts format("  %-21s %8.3f ms total  %7.4f ms/op%s",
              label, elapsed * 1000, elapsed * 1000 / ROUNDS,
              intact ? "" : "  <- and it corrupted the backlog")
end

puts <<~NOTE

  The scan is O(N) but early-exits, so a job near the HEAD — which is all the
  dashboard ever shows — is already cheap. The id => index map buys O(1) on a
  lookup that was rarely slow, and pays for it on every shift. Only id => node
  wins both, because it never stores a position to begin with.
NOTE
