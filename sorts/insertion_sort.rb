# =============================================================================
# Insertion Sort — O(n²), best O(n²) sort in practice
# =============================================================================
#
# Strategy: Build the sorted array one element at a time. Pick the next
# unsorted element and INSERT it into its correct position among the
# already-sorted elements.
#
# When to use:
# - Small arrays (under ~32 elements) — less overhead than merge/quick sort
# - Nearly sorted data — O(n) in this case
# - Tim sort uses it for small chunks (MIN_RUN)
# - Online sorting — can sort as data arrives
#
# When NOT to use:
# - Large random arrays — O(n²) is too slow
#
# How it works — like sorting playing cards in your hand:
#
#   [5, 3, 8, 1]
#    ↑ sorted
#
#   Step 1: pick 3, insert into sorted region
#     [5, 3, 8, 1]   3 < 5? yes → shift 5 right, insert 3
#     [3, 5, 8, 1]
#     ──── sorted
#
#   Step 2: pick 8, insert into sorted region
#     [3, 5, 8, 1]   8 > 5? yes → already in place
#     [3, 5, 8, 1]
#     ─────── sorted
#
#   Step 3: pick 1, insert into sorted region
#     [3, 5, 8, 1]   1 < 8? shift. 1 < 5? shift. 1 < 3? shift. Insert at 0
#     [1, 3, 5, 8]
#     ────────── sorted
#
# Why it beats bubble sort:
# - Bubble sort always does ~n comparisons per pass
# - Insertion sort stops comparing as soon as it finds the right spot
# - On nearly-sorted data, each element moves very little → O(n) total
#
# Complexity:
#   Time:  O(n²) average/worst, O(n) best (already sorted)
#   Space: O(1) — in place
#   Stable: Yes
#
# =============================================================================

def insertion_sort(arr)
  arr = arr.dup
  n = arr.length

  (1...n).each do |i|
    key = arr[i]
    j = i - 1

    # Shift elements right until we find the correct position
    while j >= 0 && arr[j] > key
      arr[j + 1] = arr[j]
      j -= 1
    end

    arr[j + 1] = key
  end

  arr
end

pp insertion_sort([5, 3, 8, 1, 9, 2, 7, 4])
# => [1, 2, 3, 4, 5, 7, 8, 9]

pp insertion_sort([])
# => []

pp insertion_sort([1, 2, 3])
# => [1, 2, 3]  (O(n) — no shifts needed)

# =============================================================================
# ASCII Animation — run: ruby sorts/insertion_sort.rb --animate
# =============================================================================

if ARGV.include?("--animate")
  require_relative 'animation_player'

  player = AnimationPlayer.new
  arr = [5, 3, 8, 1, 9, 2, 7, 4]
  work = arr.dup
  n = work.length

  player.add_frame("INSERTION SORT — Original array") { |o| o << render_bars(work) }

  (1...n).each do |i|
    key = work[i]

    player.add_frame("Step #{i}: pick #{key}, find its position in sorted region") do |o|
      colors = {}
      (0...i).each { |k| colors[k] = "\e[36m" }  # cyan = sorted region
      colors[i] = "\e[33m"  # yellow = current element
      o << render_bars(work, colors: colors)
      o << "\n  Sorted region: #{work[0...i].inspect}  Inserting: #{key}\n"
    end

    j = i - 1
    while j >= 0 && work[j] > key
      work[j + 1] = work[j]

      player.add_frame("Step #{i}: #{work[j + 1]} > #{key}, shift right") do |o|
        colors = {}
        (0..j).each { |k| colors[k] = "\e[36m" }
        colors[j + 1] = "\e[31m"  # red = shifted
        o << render_bars(work, colors: colors)
        o << "\n  Shifting #{work[j + 1]} right to make room for #{key}\n"
      end

      j -= 1
    end

    work[j + 1] = key

    player.add_frame("Step #{i}: insert #{key} at position #{j + 1}") do |o|
      colors = {}
      (0..i).each { |k| colors[k] = "\e[36m" }
      colors[j + 1] = "\e[32m"  # green = just inserted
      o << render_bars(work, colors: colors)
      o << "\n  Sorted so far: #{work[0..i].inspect}\n"
    end
  end

  player.add_frame("INSERTION SORT — Sorted!") do |o|
    o << render_bars(work, highlight: (0...n).to_a)
  end

  player.play
end
