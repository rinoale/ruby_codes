# =============================================================================
# Tim Sort — O(n log n) guaranteed, stable, hybrid
# =============================================================================
#
# Strategy: Combine insertion sort (fast on small/nearly-sorted data) with
# merge sort (efficient for combining sorted chunks).
#
# This is what Ruby, Python, Java, and JavaScript use as their default sort.
# Invented by Tim Peters in 2002 for Python.
#
# When to use:
# - General purpose — it's the default for a reason
# - Real-world data that often has partially sorted "runs"
# - Need stability (equal elements keep original order)
#
# Why it's faster than pure merge sort in practice:
# - Real data is rarely random — it has natural sorted sequences
# - Insertion sort beats merge sort on small arrays (less overhead)
# - Finding and exploiting existing runs avoids redundant work
#
# Why mix insertion sort + merge sort?
#
# Each sort has a strength that covers the other's weakness:
#
#   Insertion sort: Almost no overhead. No recursion, no extra arrays.
#   For small arrays (<32), it's faster than merge sort because merge sort's
#   constant overhead (splitting, allocating, merging) costs more than
#   the extra comparisons.
#
#     Array size 8:
#       Insertion sort: ~28 comparisons, 0 allocations, 0 function calls
#       Merge sort:     ~17 comparisons, 14 allocations, 15 function calls
#       Fewer comparisons doesn't help if you spend more time on overhead.
#
#   Merge sort: Scales. O(n log n) beats O(n²) as arrays get large.
#   At size 1000: insertion sort ~500,000 comparisons, merge sort ~10,000.
#
#   Tim sort uses each one ONLY where it's optimal:
#
#                     insertion sort wins     merge sort wins
#                     (low overhead)          (better scaling)
#                           ↓                      ↓
#   Performance  │ insertion ╲
#                │ sort       ╲    merge sort
#                │             ╲ ╱
#                │              ╳
#                │             ╱ ╲
#                │            ╱    ╲
#                │           ╱      insertion sort
#                └────────────────────────────────
#                           ~32              array size
#
#   Plus the run detection bonus: merge sort blindly splits. Tim sort
#   looks at the data first — if sequences are already sorted, it skips
#   the insertion sort step entirely. That's free work saved.
#
# How it works:
#
#   The key insight: real data has natural "runs" — sequences that are
#   already sorted. Tim sort FINDS these runs and MERGES them.
#
#   Input: [3, 5, 7, 1, 2, 8, 4, 6, 9, 10, 11]
#
#   Step 1: IDENTIFY RUNS — find naturally sorted sequences
#
#   [3, 5, 7 | 1, 2, 8 | 4, 6, 9, 10, 11]
#    run 1     run 2     run 3
#    (ascending)(ascending)(ascending)
#
#   If a run is shorter than MIN_RUN (typically 32), extend it using
#   insertion sort. Insertion sort is O(n²) in general but O(n) on
#   nearly-sorted data — perfect for small chunks.
#
#   Step 2: MERGE RUNS — combine using merge sort's merge
#
#   [3, 5, 7] + [1, 2, 8] → [1, 2, 3, 5, 7, 8]
#   [1, 2, 3, 5, 7, 8] + [4, 6, 9, 10, 11] → [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
#
#   Comparison with pure merge sort on same input:
#
#   Merge sort: splits blindly in half, ignores existing order
#     [3,5,7,1,2,8] [4,6,9,10,11]
#     [3,5,7] [1,2,8] [4,6,9] [10,11]
#     [3] [5,7] [1] [2,8] [4] [6,9] [10] [11]
#     ... many unnecessary splits and merges
#
#   Tim sort: reuses existing runs
#     [3,5,7] [1,2,8] [4,6,9,10,11]   ← found 3 runs, no splitting needed
#     merge run1+run2, then merge with run3
#     ... fewer operations because we exploited existing order
#
#   On already-sorted input:
#     Merge sort: O(n log n) — splits and re-merges everything
#     Tim sort:   O(n) — finds one big run, nothing to merge!
#
#   Algorithm details:
#
#   MIN_RUN = 32 (in practice, chosen to be 32-64 for optimal performance)
#
#   For this demo, MIN_RUN = 4 (so we can see the behavior on small arrays)
#
#   Descending runs are reversed to become ascending:
#     [8, 5, 3, 1] → detected as descending run → reversed to [1, 3, 5, 8]
#
# Complexity:
#   Time:  O(n log n) worst, O(n) best (already sorted)
#   Space: O(n) — for merging
#   Stable: Yes
#
# =============================================================================

MIN_RUN = 4  # small for demo; real implementations use 32-64

# Insertion sort on arr[left..right]
# Fast on small or nearly-sorted data
def insertion_sort(arr, left, right)
  (left + 1..right).each do |i|
    key = arr[i]
    j = i - 1
    while j >= left && arr[j] > key
      arr[j + 1] = arr[j]
      j -= 1
    end
    arr[j + 1] = key
  end
end

# Merge two sorted sub-arrays: arr[left..mid] and arr[mid+1..right]
def merge_runs(arr, left, mid, right)
  left_arr = arr[left..mid]
  right_arr = arr[mid + 1..right]

  i = 0
  j = 0
  k = left

  while i < left_arr.length && j < right_arr.length
    if left_arr[i] <= right_arr[j]  # <= for stability
      arr[k] = left_arr[i]
      i += 1
    else
      arr[k] = right_arr[j]
      j += 1
    end
    k += 1
  end

  while i < left_arr.length
    arr[k] = left_arr[i]
    i += 1
    k += 1
  end

  while j < right_arr.length
    arr[k] = right_arr[j]
    j += 1
    k += 1
  end
end

def tim_sort(arr)
  arr = arr.dup
  n = arr.length
  return arr if n <= 1

  # Step 1: Sort small runs with insertion sort
  (0...n).step(MIN_RUN) do |start|
    finish = [start + MIN_RUN - 1, n - 1].min
    insertion_sort(arr, start, finish)
  end

  # Step 2: Merge runs, doubling size each pass
  size = MIN_RUN
  while size < n
    (0...n).step(size * 2) do |left|
      mid = [left + size - 1, n - 1].min
      right = [left + 2 * size - 1, n - 1].min

      merge_runs(arr, left, mid, right) if mid < right
    end
    size *= 2
  end

  arr
end

pp tim_sort([5, 3, 8, 1, 9, 2, 7, 4])
# => [1, 2, 3, 4, 5, 7, 8, 9]

pp tim_sort([])
# => []

pp tim_sort([1])
# => [1]

pp tim_sort([3, 1])
# => [1, 3]

# Already sorted — tim sort's best case
pp tim_sort((1..20).to_a)
# => [1, 2, 3, ..., 20]

# Reverse sorted
pp tim_sort((1..20).to_a.reverse)
# => [1, 2, 3, ..., 20]

# =============================================================================
# ASCII Animation — run: ruby sorts/tim_sort.rb --animate
# =============================================================================

if ARGV.include?("--animate")
  require_relative 'animation_player'

  player = AnimationPlayer.new
  arr = [5, 3, 8, 1, 9, 2, 7, 4, 6, 10, 12, 11]

  def render_tim_bars(arr, run_ranges: [], active: nil, sorted_range: nil)
    out = ""
    arr.each_with_index do |val, i|
      bar = "█" * (val * 2)
      color = if active && active.include?(i)
                "\e[33m"   # yellow = active operation
              elsif sorted_range && sorted_range.include?(i)
                "\e[32m"   # green = sorted/merged
              elsif run_ranges.any? { |r| r.include?(i) }
                run_idx = run_ranges.index { |r| r.include?(i) }
                ["\e[36m", "\e[35m", "\e[34m", "\e[37m"][run_idx % 4]  # cycle colors per run
              else
                "\e[37m"
              end
      out << "#{color}  #{val.to_s.rjust(2)} #{bar}\e[0m\n"
    end
    out
  end

  player.add_frame("TIM SORT — Original array (#{arr.length} elements)") do |o|
    o << render_tim_bars(arr)
    o << "\n  Tim sort = insertion sort on small chunks + merge sort to combine\n"
    o << "  MIN_RUN = #{MIN_RUN}\n"
  end

  work = arr.dup
  n = work.length

  # Step 1: Show insertion sort on each run
  runs = []
  (0...n).step(MIN_RUN) do |start|
    finish = [start + MIN_RUN - 1, n - 1].min
    runs << (start..finish)
  end

  player.add_frame("Step 1: Divide into runs of size #{MIN_RUN}") do |o|
    o << render_tim_bars(work, run_ranges: runs)
    o << "\n  Runs: #{runs.map { |r| work[r].inspect }.join('  ')}\n"
  end

  runs.each_with_index do |run, ri|
    player.add_frame("Step 1: Insertion sort run #{ri + 1}: #{work[run].inspect}") do |o|
      o << render_tim_bars(work, active: run.to_a)
    end

    insertion_sort(work, run.first, run.last)

    player.add_frame("Step 1: Run #{ri + 1} sorted: #{work[run].inspect}") do |o|
      o << render_tim_bars(work, sorted_range: run.to_a)
    end
  end

  player.add_frame("Step 1 done: All runs sorted individually") do |o|
    o << render_tim_bars(work, run_ranges: runs)
    o << "\n  Runs: #{runs.map { |r| work[r].inspect }.join('  ')}\n"
  end

  # Step 2: Merge passes
  size = MIN_RUN
  pass = 1
  while size < n
    player.add_frame("Step 2, Pass #{pass}: Merge adjacent runs (size #{size} → #{size * 2})") do |o|
      o << render_tim_bars(work)
    end

    (0...n).step(size * 2) do |left|
      mid = [left + size - 1, n - 1].min
      right = [left + 2 * size - 1, n - 1].min

      if mid < right
        left_run = work[left..mid]
        right_run = work[mid + 1..right]

        player.add_frame("Merging: #{left_run.inspect} + #{right_run.inspect}") do |o|
          o << render_tim_bars(work, active: (left..right).to_a)
        end

        merge_runs(work, left, mid, right)

        player.add_frame("Merged: #{work[left..right].inspect}") do |o|
          o << render_tim_bars(work, sorted_range: (left..right).to_a)
        end
      end
    end

    size *= 2
    pass += 1
  end

  player.add_frame("TIM SORT — Sorted!") do |o|
    o << render_tim_bars(work, sorted_range: (0...n).to_a)
    o << "\n  Result: #{work.inspect}\n"
  end

  player.play
end
