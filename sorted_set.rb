# A miniature Redis sorted set (zset), structured the way Redis structures it:
#
#   1. a Hash      member => score          (answers ZSCORE in O(1))
#   2. a skip list ordered by [score, member] (answers ZRANGEBYSCORE in O(log n))
#
# Two indexes over the same entries, kept in sync by zadd/zrem — a hash index
# for exact lookups, an ordered index for ranges. Neither can do the other's
# job: a hash scatters keys on purpose, so it cannot answer "everything
# between 0 and 930" without a full scan; the ordered list can, but finding
# one member's score in it would cost a walk.
#
# The skip list: lane 0 is a plain sorted linked list holding every node.
# Each higher lane is an "express lane" that skips nodes; at insert time a
# node flips coins to decide how many lanes it joins (50% per extra lane
# here; Redis uses 25% and up to 32 lanes). A search starts on the top lane,
# rides while the next node is still too small, drops a lane when it would
# overshoot — O(log n) expected, no rebalancing ever.
#
# Unlike the Rust version (~/git/rust-exercise/sorted_set), nodes here hold
# direct references to each other — the textbook linked-structure picture.

MAX_LEVEL = 4

Node = Struct.new(:member, :score, :forward) do
  # forward[l] = next node on lane l (or nil). forward.size = lanes joined.
  def lanes = forward.size
end

class SkipList
  def initialize(rng)
    @head = Node.new(nil, -Float::INFINITY, Array.new(MAX_LEVEL))
    @level = 1
    @rng = rng
  end

  # Skip-list order is [score, then member] so equal scores still have one
  # deterministic position — same tie-break as Redis.
  def comes_before?(node, score, member)
    node.score < score || (node.score == score && node.member < member)
  end

  # Walk from HEAD to the last node sorting before [score, member],
  # remembering the drop-off node on every lane. Insert, remove and range
  # all start with this same descent.
  def descend(score, member, trace: nil)
    path = Array.new(MAX_LEVEL, @head)
    cur = @head
    (@level - 1).downto(0) do |l|
      moves = []
      while (nxt = cur.forward[l]) && comes_before?(nxt, score, member)
        moves << nxt.member
        cur = nxt
      end
      path[l] = cur
      trace << "    lane #{l}: #{moves.empty? ? '(overshoots immediately, drop down)' : "ride to #{moves.join(' -> ')}"}" if trace
    end
    path
  end

  def insert(member, score)
    path = descend(score, member)
    lanes = random_level
    if lanes > @level
      (@level...lanes).each { |l| path[l] = @head }
      @level = lanes
    end
    node = Node.new(member, score, Array.new(lanes))
    lanes.times do |l|
      node.forward[l] = path[l].forward[l]
      path[l].forward[l] = node
    end
  end

  def remove(member, score)
    path = descend(score, member)
    target = path[0].forward[0]
    return unless target && target.member == member

    # path[l] is the node just before target on lane l; bypass it.
    # Nothing else references target afterwards, so GC reclaims it.
    target.lanes.times { |l| path[l].forward[l] = target.forward[l] }
    @level -= 1 while @level > 1 && @head.forward[@level - 1].nil?
  end

  # ZRANGEBYSCORE: one O(log n) descent to just before min, then a plain
  # lane-0 walk collecting until the score passes max.
  def range_by_score(min, max, trace: nil)
    cur = descend(min, "", trace: trace)[0].forward[0]
    out = []
    while cur && cur.score <= max
      out << [cur.member, cur.score]
      cur = cur.forward[0]
    end
    out
  end

  # Draw every lane. A node appears on lane l only if it joined it;
  # otherwise its column is dashes — the "express lane skips it" picture.
  def diagram
    order = []
    cur = @head.forward[0]
    while cur
      order << cur
      cur = cur.forward[0]
    end
    labels = order.map { |n| "[#{n.member} #{n.score.to_i}]" }
    (@level - 1).downto(0).map do |l|
      row = order.each_with_index.map do |n, col|
        n.lanes > l ? "-->#{labels[col]}" : "---#{'-' * labels[col].size}"
      end
      "  lane #{l}: HEAD#{row.join}--> nil\n"
    end.join
  end

  private

  # Coin-flip promotion: 1 lane with p=1/2, 2 with 1/4, 3 with 1/8...
  def random_level
    level = 1
    level += 1 while level < MAX_LEVEL && @rng.rand < 0.5
    level
  end
end

# The zset itself: the dict and the skip list, kept in sync.
class ZSet
  def initialize(seed: 7)
    @scores = {}                       # hash index: member => score
    @list = SkipList.new(Random.new(seed)) # ordered index: [score, member]
  end

  attr_reader :list

  # ZADD. Updating an existing member means relocating it in the skip
  # list — remove at the old score, insert at the new one.
  def zadd(member, score)
    old = @scores[member]
    @list.remove(member, old) if old
    @scores[member] = score
    @list.insert(member, score)
  end

  # ZSCORE — the Hash's entire reason to exist. The list is not consulted.
  def zscore(member) = @scores[member]

  def zrem(member)
    score = @scores.delete(member)
    @list.remove(member, score) if score
  end

  def zrange_by_score(min, max, trace: nil) = @list.range_by_score(min, max, trace: trace)
end

# --- Demo: the pending-expiry scheduler pattern (score = due timestamp) ---

zset = ZSet.new
{ "job:email" => 905, "session:42" => 910, "job:retry" => 925,
  "job:report" => 930, "token:9" => 945, "cache:warm" => 960 }
  .each { |member, due| zset.zadd(member, due) }

puts "ZADD six items (score = due timestamp). The skip list lanes:\n\n"
puts zset.list.diagram
puts "  Lane 0 holds everything in score order. Higher lanes skip nodes;"
puts "  which nodes joined which lanes was decided by coin flips at insert.\n\n"

puts "ZSCORE session:42 -> #{zset.zscore('session:42')}   (Hash hit, the list is not consulted)\n\n"

trace = []
late = zset.zrange_by_score(940, 1000, trace: trace)
puts 'ZRANGEBYSCORE 940 1000 — the descent rides express lanes, then drops:'
puts trace
late.each { |member, score| puts "    found: #{member} (score #{score})" }

now = 930
due = zset.zrange_by_score(-Float::INFINITY, now)
puts "\nZRANGEBYSCORE -inf #{now}  (\"what is due?\"):"
due.each { |member, score| puts "    due: #{member} (score #{score})" }

puts "\nProcess the due items, ZREM each, and the lanes heal around them:\n\n"
due.each { |member, _| zset.zrem(member) }
puts zset.list.diagram

puts "\nZADD token:9 990 (re-schedule an existing member = remove + reinsert):\n\n"
zset.zadd("token:9", 990)
puts zset.list.diagram
