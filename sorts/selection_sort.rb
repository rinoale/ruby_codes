# =============================================================================
# Selection Sort — O(n²), simple but rarely used
# =============================================================================
#
# Strategy: Find the minimum element, put it first. Find the next minimum,
# put it second. Repeat.
#
# When to use:
# - Teaching — very intuitive
# - When number of swaps must be minimal (exactly n-1 swaps)
# - Almost never in practice — insertion sort is better in every way
#
# When NOT to use:
# - Pretty much everywhere. Insertion sort is faster on nearly-sorted data
#   and has the same worst case.
#
# How it works:
#
#   [5, 3, 8, 1]
#
#   Pass 1: scan all, find min = 1, swap with position 0
#     [5, 3, 8, 1]  →  min is 1 at index 3  →  swap with index 0
#     [1, 3, 8, 5]
#     ↑ sorted
#
#   Pass 2: scan from index 1, find min = 3, already in position
#     [1, 3, 8, 5]  →  min is 3 at index 1  →  no swap needed
#     [1, 3, 8, 5]
#     ──── sorted
#
#   Pass 3: scan from index 2, find min = 5, swap with position 2
#     [1, 3, 8, 5]  →  min is 5 at index 3  →  swap with index 2
#     [1, 3, 5, 8]
#     ────────── sorted
#
# Key difference from insertion sort:
# - Selection sort: scans UNSORTED region to find the minimum
# - Insertion sort: takes next element, scans SORTED region to place it
# - Selection always does n² comparisons, insertion can short-circuit
#
# Complexity:
#   Time:  O(n²) — always (no best-case optimization possible)
#   Space: O(1) — in place
#   Stable: No (swapping can reorder equal elements)
#
# =============================================================================

def selection_sort(arr)
  arr = arr.dup
  n = arr.length

  (0...n - 1).each do |i|
    min_idx = i
    (i + 1...n).each do |j|
      min_idx = j if arr[j] < arr[min_idx]
    end
    arr[i], arr[min_idx] = arr[min_idx], arr[i] if min_idx != i
  end

  arr
end

pp selection_sort([5, 3, 8, 1, 9, 2, 7, 4])
# => [1, 2, 3, 4, 5, 7, 8, 9]

pp selection_sort([])
# => []

pp selection_sort([1, 2, 3])
# => [1, 2, 3]

# =============================================================================
# ASCII Animation — run: ruby sorts/selection_sort.rb --animate
# =============================================================================

if ARGV.include?("--animate")
  require_relative 'animation_player'

  player = AnimationPlayer.new
  arr = [5, 3, 8, 1, 9, 2, 7, 4]
  work = arr.dup
  n = work.length

  player.add_frame("SELECTION SORT — Original array") { |o| o << render_bars(work) }

  (0...n - 1).each do |i|
    min_idx = i

    # Show scanning
    (i + 1...n).each do |j|
      min_idx = j if work[j] < work[min_idx]
    end

    player.add_frame("Pass #{i + 1}: scan unsorted region, found min = #{work[min_idx]} at index #{min_idx}") do |o|
      colors = {}
      (0...i).each { |k| colors[k] = "\e[32m" }    # green = sorted
      colors[min_idx] = "\e[33m"                      # yellow = minimum found
      colors[i] = "\e[36m" if i != min_idx            # cyan = swap target
      o << render_bars(work, colors: colors)
      o << "\n  Sorted: #{work[0...i].inspect}  Min in unsorted: #{work[min_idx]}\n"
    end

    if min_idx != i
      player.add_frame("Pass #{i + 1}: swap #{work[i]} ↔ #{work[min_idx]}") do |o|
        colors = {}
        (0...i).each { |k| colors[k] = "\e[32m" }
        colors[i] = "\e[33m"
        colors[min_idx] = "\e[33m"
        o << render_bars(work, colors: colors)
      end

      work[i], work[min_idx] = work[min_idx], work[i]
    end

    player.add_frame("Pass #{i + 1}: #{work[i]} placed at position #{i}") do |o|
      colors = {}
      (0..i).each { |k| colors[k] = "\e[32m" }
      o << render_bars(work, colors: colors)
      o << "\n  Sorted so far: #{work[0..i].inspect}\n"
    end
  end

  player.add_frame("SELECTION SORT — Sorted!") do |o|
    o << render_bars(work, highlight: (0...n).to_a)
  end

  player.play
end
