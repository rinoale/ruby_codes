# =============================================================================
# Heap Sort — O(n log n) guaranteed, in-place
# =============================================================================
#
# Strategy: Build a max-heap, then repeatedly extract the maximum.
# A heap is a binary tree where every parent is larger than its children (max-heap).
# Stored as a flat array — no nodes or pointers needed.
#
# When to use:
# - Need guaranteed O(n log n) with O(1) extra space (in-place)
# - Need to find top K elements efficiently
# - Priority queues
#
# When NOT to use:
# - Need a stable sort (heap sort is not stable)
# - Cache performance matters (heap jumps around in memory — poor locality)
# - In practice, quicksort is usually faster despite same Big-O
#
# How the array maps to a tree:
#
#   Array: [9, 7, 8, 3, 2, 5, 4, 1]
#   Index:  0  1  2  3  4  5  6  7
#
#   For index i:
#     parent:      (i - 1) / 2
#     left child:  2 * i + 1
#     right child: 2 * i + 2
#
#   As a tree:
#
#              9 [0]
#            /       \
#         7 [1]      8 [2]
#         /   \      /   \
#      3 [3] 2 [4] 5 [5] 4 [6]
#      /
#   1 [7]
#
# How it works:
#
#   Step 1: BUILD MAX-HEAP — rearrange array so parent >= children
#
#     Start: [5, 3, 8, 1, 9, 2, 7, 4]
#
#              5                        9
#            /   \                    /   \
#           3     8      ──→        4     8
#          / \   / \              /  \   / \
#         1   9 2   7            1    3 2   7
#        /                      /
#       4                      5
#
#     After heapify: [9, 4, 8, 5, 3, 2, 7, 1]
#     (every parent >= its children)
#
#   Step 2: EXTRACT MAX — swap root with last, shrink heap, fix heap
#
#     Round 1: swap 9 ↔ 1, heap size 7
#       [1, 4, 8, 5, 3, 2, 7 | 9]
#        fix heap → [8, 4, 7, 5, 3, 2, 1 | 9]
#
#     Round 2: swap 8 ↔ 1, heap size 6
#       [1, 4, 7, 5, 3, 2 | 8, 9]
#        fix heap → [7, 4, 2, 5, 3, 1 | 8, 9]
#
#     Round 3: swap 7 ↔ 1, heap size 5
#       [1, 4, 2, 5, 3 | 7, 8, 9]
#        fix heap → [5, 4, 2, 1, 3 | 7, 8, 9]
#
#     ... continues until heap size is 1
#
#     Final: [1, 2, 3, 4, 5, 7, 8, 9]
#
#   The "|" marks the boundary — left side is unsorted heap,
#   right side is sorted result growing from the end.
#
# Complexity:
#   Time:  O(n log n) — always (best, average, worst)
#   Space: O(1) — sorts in place, no extra arrays
#
# =============================================================================

def heap_sort(arr)
  arr = arr.dup  # don't mutate the original
  n = arr.length

  # Step 1: Build max-heap (start from last non-leaf node, work backwards)
  (n / 2 - 1).downto(0) { |i| heapify(arr, n, i) }

  # Step 2: Extract max one by one
  (n - 1).downto(1) do |i|
    arr[0], arr[i] = arr[i], arr[0]  # swap max (root) to the end
    heapify(arr, i, 0)               # fix the reduced heap
  end

  arr
end

# Push element at index i down to its correct position in the heap
# heap_size limits which portion of the array is still a heap
def heapify(arr, heap_size, i)
  largest = i
  left = 2 * i + 1
  right = 2 * i + 2

  largest = left if left < heap_size && arr[left] > arr[largest]
  largest = right if right < heap_size && arr[right] > arr[largest]

  if largest != i
    arr[i], arr[largest] = arr[largest], arr[i]  # swap
    heapify(arr, heap_size, largest)              # recurse down
  end
end

pp heap_sort([5, 3, 8, 1, 9, 2, 7, 4])
# => [1, 2, 3, 4, 5, 7, 8, 9]

pp heap_sort([])
# => []

pp heap_sort([1])
# => [1]

pp heap_sort([3, 1])
# => [1, 3]

# Works fine on already sorted input — no worst case
pp heap_sort((1..20).to_a)
# => [1, 2, 3, 4, 5, ..., 20]

# =============================================================================
# ASCII Animation — run: ruby sorts/heap_sort.rb --animate
# =============================================================================

if ARGV.include?("--animate")
  require_relative 'animation_player'

  player = AnimationPlayer.new
  arr = [5, 3, 8, 1, 9, 2, 7, 4]

  def render_heap_bars(arr, heap_size, swap: [], sorted_from: nil)
    out = ""
    arr.each_with_index do |val, i|
      bar = "█" * (val * 3)
      color = if swap.include?(i)
                "\e[33m"        # yellow = swapping
              elsif sorted_from && i >= sorted_from
                "\e[32m"        # green = sorted
              elsif i < heap_size
                "\e[37m"        # white = heap
              else
                "\e[32m"        # green = sorted
              end
      marker = i == heap_size && heap_size < arr.length ? "  ← heap|sorted" : ""
      out << "#{color}  #{val.to_s.rjust(2)} #{bar}\e[0m#{marker}\n"
    end
    out << "\n  \e[37m■\e[0m heap  \e[33m■\e[0m swapping  \e[32m■\e[0m sorted\n"
    out
  end

  def heapify_frames(arr, heap_size, i, player)
    largest = i
    left = 2 * i + 1
    right = 2 * i + 2

    largest = left if left < heap_size && arr[left] > arr[largest]
    largest = right if right < heap_size && arr[right] > arr[largest]

    if largest != i
      player.add_frame("Heapify: comparing #{arr[i]} vs #{arr[largest]} — swap needed") do |o|
        o << render_heap_bars(arr, heap_size, swap: [i, largest])
      end

      arr[i], arr[largest] = arr[largest], arr[i]

      player.add_frame("Heapify: swapped → #{arr.inspect}") do |o|
        o << render_heap_bars(arr, heap_size, swap: [i, largest])
      end

      heapify_frames(arr, heap_size, largest, player)
    end
  end

  arr_copy = arr.dup
  n = arr_copy.length

  player.add_frame("HEAP SORT — Original array") { |o| o << render_heap_bars(arr_copy, n) }

  # Build max-heap
  player.add_frame("Step 1: Build max-heap") { |o| o << render_heap_bars(arr_copy, n) }

  (n / 2 - 1).downto(0) do |i|
    player.add_frame("Building heap: heapify from index #{i} (value #{arr_copy[i]})") do |o|
      o << render_heap_bars(arr_copy, n, swap: [i])
    end
    heapify_frames(arr_copy, n, i, player)
  end

  player.add_frame("Max-heap built! Root = #{arr_copy[0]} (maximum)") do |o|
    o << render_heap_bars(arr_copy, n)
  end

  # Extract max one by one
  (n - 1).downto(1) do |i|
    player.add_frame("Step 2: Swap root #{arr_copy[0]} ↔ last unsorted #{arr_copy[i]}") do |o|
      o << render_heap_bars(arr_copy, i + 1, swap: [0, i])
    end

    arr_copy[0], arr_copy[i] = arr_copy[i], arr_copy[0]

    player.add_frame("Swapped. Sorted so far: #{arr_copy[i..].inspect}") do |o|
      o << render_heap_bars(arr_copy, i, sorted_from: i)
    end

    heapify_frames(arr_copy, i, 0, player)

    player.add_frame("Heap fixed. Sorted: #{arr_copy[i..].inspect}") do |o|
      o << render_heap_bars(arr_copy, i, sorted_from: i)
    end
  end

  player.add_frame("HEAP SORT — Sorted!") do |o|
    o << render_heap_bars(arr_copy, 0, sorted_from: 0)
  end

  player.play
end
