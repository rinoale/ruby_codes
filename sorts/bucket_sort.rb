# =============================================================================
# Bucket Sort — O(n) average, for uniformly distributed data
# =============================================================================
#
# Strategy: Divide elements into "buckets" by range, sort each bucket
# individually (usually with insertion sort), then concatenate.
#
# When to use:
# - Data is uniformly distributed across a range (e.g., random floats 0.0-1.0)
# - Known min/max bounds
# - Large dataset where distribution is roughly even
#
# When NOT to use:
# - Skewed distribution — all elements land in one bucket → O(n²)
# - Unknown range
# - Very large range with sparse values
#
# How it works:
#
#   [0.42, 0.32, 0.23, 0.52, 0.25, 0.47, 0.51]
#   Using 5 buckets for range 0.0-1.0:
#
#   Step 1: DISTRIBUTE into buckets by range
#
#     Bucket 0 [0.0-0.2): []
#     Bucket 1 [0.2-0.4): [0.32, 0.23, 0.25]
#     Bucket 2 [0.4-0.6): [0.42, 0.52, 0.47, 0.51]
#     Bucket 3 [0.6-0.8): []
#     Bucket 4 [0.8-1.0): []
#
#   Step 2: SORT each bucket (insertion sort — small buckets)
#
#     Bucket 1: [0.23, 0.25, 0.32]
#     Bucket 2: [0.42, 0.47, 0.51, 0.52]
#
#   Step 3: CONCATENATE all buckets
#
#     [0.23, 0.25, 0.32, 0.42, 0.47, 0.51, 0.52]
#
# Why O(n) average:
#   With uniform distribution, each bucket gets ~n/k elements (k = num buckets).
#   Insertion sort on each bucket is O((n/k)²).
#   Total: k * O((n/k)²) = O(n²/k).
#   If k ≈ n, this becomes O(n).
#
# For integer version: bucket by value ranges
#
#   [35, 12, 48, 3, 27, 41, 19, 8]   range 0-50, 5 buckets
#
#     Bucket 0 [0-10):   [3, 8]
#     Bucket 1 [10-20):  [12, 19]
#     Bucket 2 [20-30):  [27]
#     Bucket 3 [30-40):  [35]
#     Bucket 4 [40-50]:  [48, 41]
#
#     Sort each → concat → [3, 8, 12, 19, 27, 35, 41, 48]
#
# Complexity:
#   Time:  O(n) average (uniform), O(n²) worst (all in one bucket)
#   Space: O(n + k) for buckets
#   Stable: Depends on inner sort
#
# =============================================================================

def bucket_sort(arr, num_buckets: nil)
  return arr.dup if arr.length <= 1

  min_val = arr.min
  max_val = arr.max
  return arr.dup if min_val == max_val

  num_buckets ||= [arr.length / 2, 1].max
  range = (max_val - min_val + 1).to_f

  buckets = Array.new(num_buckets) { [] }

  # Distribute into buckets
  arr.each do |val|
    idx = [((val - min_val) / range * num_buckets).floor, num_buckets - 1].min
    buckets[idx] << val
  end

  # Sort each bucket with insertion sort, then concatenate
  result = []
  buckets.each do |bucket|
    # Inline insertion sort
    (1...bucket.length).each do |i|
      key = bucket[i]
      j = i - 1
      while j >= 0 && bucket[j] > key
        bucket[j + 1] = bucket[j]
        j -= 1
      end
      bucket[j + 1] = key
    end
    result.concat(bucket)
  end

  result
end

pp bucket_sort([35, 12, 48, 3, 27, 41, 19, 8])
# => [3, 8, 12, 19, 27, 35, 41, 48]

pp bucket_sort([5, 3, 8, 1, 9, 2, 7, 4])
# => [1, 2, 3, 4, 5, 7, 8, 9]

pp bucket_sort([])
# => []

# =============================================================================
# ASCII Animation — run: ruby sorts/bucket_sort.rb --animate
# =============================================================================

if ARGV.include?("--animate")
  require_relative 'animation_player'

  player = AnimationPlayer.new
  arr = [35, 12, 48, 3, 27, 41, 19, 8]
  work = arr.dup
  n = work.length
  num_buckets = 5

  min_val = work.min
  max_val = work.max
  range = (max_val - min_val + 1).to_f

  player.add_frame("BUCKET SORT — Original array (#{num_buckets} buckets, range #{min_val}-#{max_val})") do |o|
    o << render_bars(work)
  end

  buckets = Array.new(num_buckets) { [] }
  bucket_ranges = num_buckets.times.map do |i|
    lo = min_val + (range * i / num_buckets).floor
    hi = min_val + (range * (i + 1) / num_buckets).floor - 1
    hi = max_val if i == num_buckets - 1
    [lo, hi]
  end

  # Step 1: Distribute
  work.each_with_index do |val, vi|
    idx = [((val - min_val) / range * num_buckets).floor, num_buckets - 1].min
    buckets[idx] << val

    player.add_frame("Step 1: #{val} → Bucket #{idx} (range #{bucket_ranges[idx][0]}-#{bucket_ranges[idx][1]})") do |o|
      colors = {}
      colors[vi] = "\e[33m"
      o << render_bars(work, colors: colors)
      o << "\n"
      buckets.each_with_index do |b, bi|
        color = bi == idx ? "\e[33m" : "\e[36m"
        o << "  #{color}Bucket #{bi} [#{bucket_ranges[bi][0]}-#{bucket_ranges[bi][1]}]: #{b.inspect}\e[0m\n"
      end
    end
  end

  player.add_frame("Step 1 done: All elements distributed") do |o|
    buckets.each_with_index do |b, bi|
      o << "  \e[36mBucket #{bi} [#{bucket_ranges[bi][0]}-#{bucket_ranges[bi][1]}]: #{b.inspect}\e[0m\n"
    end
  end

  # Step 2: Sort each bucket
  buckets.each_with_index do |bucket, bi|
    next if bucket.length <= 1

    player.add_frame("Step 2: Sort Bucket #{bi}: #{bucket.inspect} (insertion sort)") do |o|
      buckets.each_with_index do |b, bj|
        color = bj == bi ? "\e[33m" : "\e[36m"
        o << "  #{color}Bucket #{bj}: #{b.inspect}\e[0m\n"
      end
    end

    # Sort in place
    (1...bucket.length).each do |i|
      key = bucket[i]
      j = i - 1
      while j >= 0 && bucket[j] > key
        bucket[j + 1] = bucket[j]
        j -= 1
      end
      bucket[j + 1] = key
    end

    player.add_frame("Step 2: Bucket #{bi} sorted: #{bucket.inspect}") do |o|
      buckets.each_with_index do |b, bj|
        color = bj == bi ? "\e[32m" : "\e[36m"
        o << "  #{color}Bucket #{bj}: #{b.inspect}\e[0m\n"
      end
    end
  end

  # Step 3: Concatenate
  result = buckets.flatten

  player.add_frame("Step 3: Concatenate all buckets") do |o|
    buckets.each_with_index do |b, bi|
      o << "  \e[32mBucket #{bi}: #{b.inspect}\e[0m\n"
    end
    o << "\n  → #{result.inspect}\n"
  end

  player.add_frame("BUCKET SORT — Sorted!") do |o|
    o << render_bars(result, highlight: (0...result.length).to_a)
  end

  player.play
end
