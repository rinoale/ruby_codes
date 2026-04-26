# =============================================================================
# Bubble Sort — O(n²), the simplest sort
# =============================================================================
#
# Strategy: Repeatedly walk through the array, swapping adjacent elements
# if they're in the wrong order. Largest elements "bubble up" to the end.
#
# When to use:
# - Teaching/learning — easiest to understand and implement
# - Almost never in production
#
# When NOT to use:
# - Any real-world scenario with more than ~100 elements
# - Even among O(n²) sorts, insertion sort is faster in practice
#
# How it works:
#
#   [5, 3, 8, 1]
#
#   Pass 1: bubble the largest (8) to the end
#     [5, 3, 8, 1]  →  5>3? swap  →  [3, 5, 8, 1]
#     [3, 5, 8, 1]  →  5>8? no    →  [3, 5, 8, 1]
#     [3, 5, 8, 1]  →  8>1? swap  →  [3, 5, 1, 8]  ← 8 in place
#
#   Pass 2: bubble next largest (5) into position
#     [3, 5, 1, 8]  →  3>5? no    →  [3, 5, 1, 8]
#     [3, 5, 1, 8]  →  5>1? swap  →  [3, 1, 5, 8]  ← 5 in place
#
#   Pass 3: final pass
#     [3, 1, 5, 8]  →  3>1? swap  →  [1, 3, 5, 8]  ← done!
#
#   Why "bubble": large elements float up like bubbles in water.
#   Each pass guarantees the next-largest element reaches its spot.
#
# Optimization: if a pass makes no swaps, the array is sorted — stop early.
# This gives O(n) best case on already-sorted input.
#
# Complexity:
#   Time:  O(n²) average/worst, O(n) best (already sorted, with early stop)
#   Space: O(1) — in place
#   Stable: Yes
#
# =============================================================================

def bubble_sort(arr)
  arr = arr.dup
  n = arr.length

  (n - 1).times do |i|
    swapped = false
    (0...(n - 1 - i)).each do |j|
      if arr[j] > arr[j + 1]
        arr[j], arr[j + 1] = arr[j + 1], arr[j]
        swapped = true
      end
    end
    break unless swapped  # early stop if no swaps
  end

  arr
end

pp bubble_sort([5, 3, 8, 1, 9, 2, 7, 4])
# => [1, 2, 3, 4, 5, 7, 8, 9]

pp bubble_sort([])
# => []

pp bubble_sort([1, 2, 3])
# => [1, 2, 3]  (early stop — O(n))

# =============================================================================
# ASCII Animation — run: ruby sorts/bubble_sort.rb --animate
# =============================================================================

if ARGV.include?("--animate")
  require_relative 'animation_player'

  player = AnimationPlayer.new
  arr = [5, 3, 8, 1, 9, 2, 7, 4]
  work = arr.dup
  n = work.length

  player.add_frame("BUBBLE SORT — Original array") { |o| o << render_bars(work) }

  (n - 1).times do |i|
    swapped = false
    (0...(n - 1 - i)).each do |j|
      # Show comparison
      player.add_frame("Pass #{i + 1}: compare #{work[j]} vs #{work[j + 1]}") do |o|
        colors = {}
        colors[j] = "\e[33m"      # yellow = comparing
        colors[j + 1] = "\e[33m"
        (n - i...n).each { |k| colors[k] = "\e[32m" }  # green = sorted
        o << render_bars(work, colors: colors)
        o << "\n  #{work[j]} > #{work[j + 1]}? #{work[j] > work[j + 1] ? 'Yes → swap' : 'No'}\n"
      end

      if work[j] > work[j + 1]
        work[j], work[j + 1] = work[j + 1], work[j]
        swapped = true

        player.add_frame("Pass #{i + 1}: swapped → #{work[j]} #{work[j + 1]}") do |o|
          colors = {}
          colors[j] = "\e[36m"      # cyan = just swapped
          colors[j + 1] = "\e[36m"
          (n - i...n).each { |k| colors[k] = "\e[32m" }
          o << render_bars(work, colors: colors)
        end
      end
    end

    player.add_frame("Pass #{i + 1} done. #{work[n - 1 - i]} bubbled to position #{n - 1 - i}") do |o|
      colors = {}
      (n - 1 - i...n).each { |k| colors[k] = "\e[32m" }
      o << render_bars(work, colors: colors)
    end

    break unless swapped
  end

  player.add_frame("BUBBLE SORT — Sorted!") do |o|
    o << render_bars(work, highlight: (0...n).to_a)
  end

  player.play
end
