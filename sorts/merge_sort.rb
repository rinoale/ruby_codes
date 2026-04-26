# =============================================================================
# Merge Sort — O(n log n) guaranteed
# =============================================================================
#
# Strategy: Divide and conquer.
# Split the array in half recursively until single elements, then merge
# the halves back together in sorted order.
#
# When to use:
# - Need guaranteed O(n log n) — no worst-case degradation
# - Need a stable sort (equal elements keep their original order)
# - Sorting linked lists (merge is O(1) extra space with linked lists)
# - External sorting (sorting data that doesn't fit in memory)
#
# Trade-off: Uses O(n) extra memory for the merge step.
#
# How it works:
#
#   [5, 3, 8, 1, 9, 2, 7, 4]          ← original
#
#   Step 1: DIVIDE — split in half recursively
#
#   [5, 3, 8, 1, 9, 2, 7, 4]
#          /              \
#   [5, 3, 8, 1]    [9, 2, 7, 4]
#     /      \         /      \
#   [5, 3]  [8, 1]  [9, 2]  [7, 4]
#    / \     / \     / \      / \
#   [5] [3] [8] [1] [9] [2] [7] [4]    ← single elements (base case)
#
#   Step 2: MERGE — combine pairs in sorted order
#
#   [5] [3] [8] [1] [9] [2] [7] [4]
#    \ /     \ /     \ /      \ /
#   [3, 5]  [1, 8]  [2, 9]  [4, 7]     ← merge pairs
#      \      /         \      /
#   [1, 3, 5, 8]    [2, 4, 7, 9]       ← merge again
#          \              /
#   [1, 2, 3, 4, 5, 7, 8, 9]           ← final merge
#
#   The merge step (combining two sorted arrays):
#
#   left:  [1, 3, 5, 8]    right: [2, 4, 7, 9]
#           ^                       ^
#   Compare 1 vs 2 → take 1   result: [1]
#              ^                ^
#   Compare 3 vs 2 → take 2   result: [1, 2]
#              ^                   ^
#   Compare 3 vs 4 → take 3   result: [1, 2, 3]
#                 ^                ^
#   Compare 5 vs 4 → take 4   result: [1, 2, 3, 4]
#                 ^                   ^
#   Compare 5 vs 7 → take 5   result: [1, 2, 3, 4, 5]
#                    ^                ^
#   Compare 8 vs 7 → take 7   result: [1, 2, 3, 4, 5, 7]
#                    ^                   ^
#   Compare 8 vs 9 → take 8   result: [1, 2, 3, 4, 5, 7, 8]
#                                        ^
#   Remaining: 9               result: [1, 2, 3, 4, 5, 7, 8, 9]
#
# Complexity:
#   Time:  O(n log n) — always (best, average, worst)
#   Space: O(n) — needs temporary arrays for merging
#
# =============================================================================

def merge_sort(arr)
  return arr if arr.length <= 1

  mid = arr.length / 2
  left = merge_sort(arr[0...mid])
  right = merge_sort(arr[mid..])

  merge(left, right)
end

def merge(left, right)
  result = []
  i = 0
  j = 0

  while i < left.length && j < right.length
    if left[i] <= right[j]
      result << left[i]
      i += 1
    else
      result << right[j]
      j += 1
    end
  end

  # Append remaining elements (one side is exhausted)
  result + left[i..] + right[j..]
end

pp merge_sort([5, 3, 8, 1, 9, 2, 7, 4])
# => [1, 2, 3, 4, 5, 7, 8, 9]

pp merge_sort([])
# => []

pp merge_sort([1])
# => [1]

pp merge_sort([3, 1])
# => [1, 3]

# =============================================================================
# ASCII Animation — run: ruby sorts/merge_sort.rb --animate
# =============================================================================

if ARGV.include?("--animate")
  require_relative 'animation_player'

  player = AnimationPlayer.new
  arr = [5, 3, 8, 1, 9, 2, 7, 4]

  player.add_frame("MERGE SORT — Original array") { |o| o << render_bars(arr) }

  # Record all frames by running merge sort with frame capture
  def merge_sort_frames(arr, player, depth: 0)
    return arr if arr.length <= 1

    mid = arr.length / 2
    left_half = arr[0...mid]
    right_half = arr[mid..]

    indent = "  " * depth
    player.add_frame("#{indent}Split: #{arr.inspect} → #{left_half.inspect} + #{right_half.inspect}") do |o|
      o << render_bars(left_half) << "\n  --- split ---\n\n" << render_bars(right_half)
    end

    left = merge_sort_frames(left_half, player, depth: depth + 1)
    right = merge_sort_frames(right_half, player, depth: depth + 1)

    # Merge with frame per step
    result = []
    i = 0
    j = 0

    while i < left.length && j < right.length
      if left[i] <= right[j]
        result << left[i]
        taken = "take #{left[i]} from left"
        i += 1
      else
        result << right[j]
        taken = "take #{right[j]} from right"
        j += 1
      end

      remaining = left[i..] + right[j..]
      current = result + remaining
      player.add_frame("Merge: #{left.inspect} + #{right.inspect} — #{taken}") do |o|
        o << render_bars(current, highlight: (0...result.length).to_a)
        o << "\n  result so far: #{result.inspect}\n"
        o << "  left remaining: #{left[i..].inspect}  right remaining: #{right[j..].inspect}\n"
      end
    end

    final = result + left[i..] + right[j..]
    player.add_frame("Merged: #{final.inspect}") do |o|
      o << render_bars(final, highlight: (0...final.length).to_a)
    end

    final
  end

  sorted = merge_sort_frames(arr, player)

  player.add_frame("MERGE SORT — Sorted!") do |o|
    o << render_bars(sorted, highlight: (0...sorted.length).to_a)
  end

  player.play
end
