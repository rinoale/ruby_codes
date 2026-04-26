# =============================================================================
# Quick Sort — O(n log n) average
# =============================================================================
#
# Strategy: Pick a pivot, partition around it.
# All elements smaller than pivot go left, larger go right. Recurse on each side.
#
# When to use:
# - General-purpose in-memory sorting (fastest in practice for most data)
# - When average-case performance matters more than worst-case guarantee
# - When memory is tight — can be done in-place with O(log n) stack space
#
# When NOT to use:
# - Already sorted or nearly sorted data (O(n²) worst case with bad pivot)
# - Need a stable sort (equal elements may be reordered)
# - External sorting (merge sort is better for disk-based data)
#
# How it works:
#
#   [5, 3, 8, 1, 9, 2, 7, 4]     pivot = 5
#
#   Step 1: PARTITION — split around pivot
#
#   less than 5:  [3, 1, 2, 4]
#   equal to 5:   [5]
#   greater than: [8, 9, 7]
#
#   Step 2: RECURSE on left and right
#
#   [3, 1, 2, 4]  pivot = 3        [8, 9, 7]  pivot = 8
#      /   |   \                      /  |  \
#   [1,2] [3] [4]                  [7]  [8] [9]
#    / \
#   [1] [2]
#
#   Step 3: CONCATENATE — results are already sorted
#
#   [1, 2] + [3] + [4] = [1, 2, 3, 4]
#   [7] + [8] + [9] = [7, 8, 9]
#   [1, 2, 3, 4] + [5] + [7, 8, 9] = [1, 2, 3, 4, 5, 7, 8, 9]
#
#   Why pivot choice matters:
#
#   GOOD pivot (near median) — balanced split:
#
#     [xxxxxxxx]          n
#      /      \
#   [xxxx]  [xxxx]        n/2 each
#    / \      / \
#   [xx][xx] [xx][xx]     n/4 each
#
#   log n levels × n work per level = O(n log n)
#
#   BAD pivot (smallest/largest) — unbalanced split:
#
#     [xxxxxxxx]          n
#      /      \
#   []  [xxxxxxx]         n-1
#        /     \
#      []  [xxxxxx]       n-2
#            ...
#
#   n levels × n work per level = O(n²)
#
#   This happens when the array is already sorted and you pick the first element.
#   Fix: use random pivot, median-of-three, or middle element.
#
# Complexity:
#   Time:  O(n log n) average, O(n²) worst case (bad pivot)
#   Space: O(log n) for recursion stack (in-place version)
#          O(n) for this simpler version (creates new arrays)
#
# =============================================================================

def quick_sort(arr)
  return arr if arr.length <= 1

  # Random pivot avoids O(n²) on sorted input
  pivot = arr[rand(arr.length)]

  less = arr.select { |x| x < pivot }
  equal = arr.select { |x| x == pivot }
  greater = arr.select { |x| x > pivot }

  quick_sort(less) + equal + quick_sort(greater)
end

pp quick_sort([5, 3, 8, 1, 9, 2, 7, 4])
# => [1, 2, 3, 4, 5, 7, 8, 9]

pp quick_sort([])
# => []

pp quick_sort([1])
# => [1]

pp quick_sort([3, 1])
# => [1, 3]

# Worst case demo — already sorted, but random pivot saves us
pp quick_sort((1..20).to_a)
# => [1, 2, 3, 4, 5, ..., 20]

# =============================================================================
# ASCII Animation — run: ruby sorts/quick_sort.rb --animate
# =============================================================================

if ARGV.include?("--animate")
  require_relative 'animation_player'

  player = AnimationPlayer.new
  arr = [5, 3, 8, 1, 9, 2, 7, 4]

  player.add_frame("QUICK SORT — Original array") { |o| o << render_bars(arr) }

  def quick_sort_frames(arr, player, depth: 0)
    return arr if arr.length <= 1

    pivot_idx = arr.length / 2
    pivot = arr[pivot_idx]

    less = arr.select { |x| x < pivot }
    equal = arr.select { |x| x == pivot }
    greater = arr.select { |x| x > pivot }

    indent = "  " * depth

    # Show partition
    colors = {}
    arr.each_with_index do |x, i|
      colors[i] = if x == pivot
                    "\e[33m"  # yellow = pivot
                  elsif x < pivot
                    "\e[32m"  # green = less
                  else
                    "\e[31m"  # red = greater
                  end
    end

    player.add_frame("#{indent}Depth #{depth}: partition around pivot = #{pivot}") do |o|
      o << render_bars(arr, colors: colors)
      o << "\n  \e[33m■\e[0m pivot (#{pivot})  \e[32m■\e[0m less #{less.inspect}  \e[31m■\e[0m greater #{greater.inspect}\n"
    end

    # Show separated groups
    player.add_frame("#{indent}Depth #{depth}: separated into 3 groups") do |o|
      o << "  \e[32mless:\e[0m\n" << render_bars(less, highlight: (0...less.length).to_a)
      o << "\n  \e[33mequal:\e[0m\n" << render_bars(equal, colors: (0...equal.length).map { |i| [i, "\e[33m"] }.to_h)
      o << "\n  \e[31mgreater:\e[0m\n" << render_bars(greater, colors: (0...greater.length).map { |i| [i, "\e[31m"] }.to_h)
    end

    sorted_less = quick_sort_frames(less, player, depth: depth + 1)
    sorted_greater = quick_sort_frames(greater, player, depth: depth + 1)

    result = sorted_less + equal + sorted_greater

    player.add_frame("#{indent}Depth #{depth}: concatenate #{sorted_less.inspect} + #{equal.inspect} + #{sorted_greater.inspect}") do |o|
      o << render_bars(result, highlight: (0...result.length).to_a)
    end

    result
  end

  sorted = quick_sort_frames(arr, player)

  player.add_frame("QUICK SORT — Sorted!") do |o|
    o << render_bars(sorted, highlight: (0...sorted.length).to_a)
  end

  player.play
end
