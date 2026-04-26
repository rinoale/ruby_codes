# =============================================================================
# Counting Sort — O(n + k), non-comparison sort
# =============================================================================
#
# Strategy: Don't compare elements at all. Count how many times each value
# appears, then rebuild the array from the counts.
#
# When to use:
# - Integer values within a known, small range (e.g., ages 0-120, scores 0-100)
# - Need O(n) performance — faster than any comparison-based sort
# - Radix sort uses counting sort as a subroutine
#
# When NOT to use:
# - Large value range (range 0..1,000,000 needs a million-element count array)
# - Floating point or string data
# - Negative numbers (needs offset adjustment)
#
# How it works:
#
#   [4, 2, 2, 8, 3, 3, 1]
#
#   Step 1: COUNT — how many of each value?
#
#     value: 0  1  2  3  4  5  6  7  8
#     count: 0  1  2  2  1  0  0  0  1
#                ↑  ↑  ↑  ↑           ↑
#               one two two one      one
#
#   Step 2: REBUILD — output each value count times
#
#     1 appears 1 time  → [1]
#     2 appears 2 times → [1, 2, 2]
#     3 appears 2 times → [1, 2, 2, 3, 3]
#     4 appears 1 time  → [1, 2, 2, 3, 3, 4]
#     8 appears 1 time  → [1, 2, 2, 3, 3, 4, 8]
#
#   No comparisons! Just counting and placing.
#
# Why O(n + k):
#   n = number of elements (to count them)
#   k = range of values (size of count array)
#   If k is small relative to n, this is effectively O(n)
#   If k >> n (e.g., sorting 10 numbers in range 0..1,000,000), it's wasteful
#
# This breaks the O(n log n) barrier because it's not comparison-based.
# The O(n log n) lower bound only applies to comparison sorts.
#
# Complexity:
#   Time:  O(n + k) where k is the range of values
#   Space: O(k) for the count array
#   Stable: Yes (with proper implementation)
#
# =============================================================================

def counting_sort(arr)
  return arr.dup if arr.length <= 1

  min = arr.min
  max = arr.max
  range = max - min + 1

  counts = Array.new(range, 0)
  arr.each { |val| counts[val - min] += 1 }

  result = []
  counts.each_with_index do |count, i|
    count.times { result << (i + min) }
  end

  result
end

pp counting_sort([4, 2, 2, 8, 3, 3, 1])
# => [1, 2, 2, 3, 3, 4, 8]

pp counting_sort([5, 3, 8, 1, 9, 2, 7, 4])
# => [1, 2, 3, 4, 5, 7, 8, 9]

pp counting_sort([])
# => []

# =============================================================================
# ASCII Animation — run: ruby sorts/counting_sort.rb --animate
# =============================================================================

if ARGV.include?("--animate")
  require_relative 'animation_player'

  player = AnimationPlayer.new
  arr = [4, 2, 2, 8, 3, 3, 1]
  work = arr.dup
  n = work.length

  player.add_frame("COUNTING SORT — Original array") { |o| o << render_bars(work) }

  min_val = work.min
  max_val = work.max
  range = max_val - min_val + 1
  counts = Array.new(range, 0)

  # Step 1: Count each element
  work.each_with_index do |val, i|
    counts[val - min_val] += 1

    player.add_frame("Step 1: Count — saw #{val}") do |o|
      colors = {}
      colors[i] = "\e[33m"
      o << render_bars(work, colors: colors)
      o << "\n  Count array:\n"
      counts.each_with_index do |c, ci|
        bar = "█" * (c * 4)
        color = ci == val - min_val ? "\e[33m" : "\e[37m"
        o << "  #{color}#{(ci + min_val).to_s.rjust(2)}: #{c} #{bar}\e[0m\n"
      end
    end
  end

  player.add_frame("Step 1 done: All elements counted") do |o|
    o << "  Count array:\n"
    counts.each_with_index do |c, ci|
      bar = "█" * (c * 4)
      o << "  \e[36m#{(ci + min_val).to_s.rjust(2)}: #{c} #{bar}\e[0m\n"
    end
  end

  # Step 2: Rebuild
  result = []
  counts.each_with_index do |count, ci|
    next if count == 0
    val = ci + min_val
    count.times { result << val }

    player.add_frame("Step 2: Rebuild — #{val} appears #{count} time(s)") do |o|
      o << render_bars(result, highlight: (0...result.length).to_a)
      o << "\n  Result so far: #{result.inspect}\n"
    end
  end

  player.add_frame("COUNTING SORT — Sorted! No comparisons needed.") do |o|
    o << render_bars(result, highlight: (0...result.length).to_a)
  end

  player.play
end
