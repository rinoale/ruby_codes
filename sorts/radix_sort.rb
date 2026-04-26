# =============================================================================
# Radix Sort — O(d * n), non-comparison sort for integers
# =============================================================================
#
# Strategy: Sort digit by digit, from least significant to most significant.
# Each digit is sorted using counting sort (which is stable — critical!).
#
# When to use:
# - Large arrays of integers or fixed-length strings
# - When the number of digits (d) is small relative to log(n)
# - Sorting IDs, phone numbers, dates, IP addresses
#
# When NOT to use:
# - Variable-length data
# - Floating point numbers (without special encoding)
# - When range of values is huge and sparse
#
# How it works:
#
#   [170, 45, 75, 90, 802, 24, 2, 66]
#
#   Sort by ones digit (rightmost):
#     17[0]  4[5]  7[5]  9[0]  80[2]  2[4]  [2]  6[6]
#     → [170, 90, 802, 2, 24, 45, 75, 66]
#       (0s, then 0s, then 2s, then 2s, then 4, then 5s, then 5, then 6)
#
#   Sort by tens digit:
#     1[7]0  [9]0  8[0]2  [0]2  [2]4  [4]5  [7]5  [6]6
#     → [802, 2, 24, 45, 66, 170, 75, 90]
#
#   Sort by hundreds digit:
#     [8]02  [0]02  [0]24  [0]45  [0]66  [1]70  [0]75  [0]90
#     → [2, 24, 45, 66, 75, 90, 170, 802]
#
#   Done! Each pass sorts by one digit using stable counting sort.
#   Stability is critical: when sorting by tens digit, elements with
#   the same tens digit keep their order from the ones sort.
#
# Why stability matters:
#
#   After sorting by ones:  [170, 90, 802, 2, ...]
#   170 comes before 90 because 0 was processed before 0... wait, same digit.
#   Actually: both have 0 in ones place. Stability means their relative
#   order from the input is preserved. When we then sort by tens, elements
#   with the same tens digit are still sorted by ones from the previous pass.
#
# Complexity:
#   Time:  O(d * n) where d = number of digits
#   Space: O(n + k) where k = base (10 for decimal)
#   Stable: Yes
#
# =============================================================================

def radix_sort(arr)
  return arr.dup if arr.length <= 1

  max_val = arr.max
  result = arr.dup

  exp = 1  # current digit place: 1, 10, 100, ...
  while max_val / exp > 0
    result = counting_sort_by_digit(result, exp)
    exp *= 10
  end

  result
end

# Stable counting sort on a specific digit position
def counting_sort_by_digit(arr, exp)
  n = arr.length
  output = Array.new(n, 0)
  count = Array.new(10, 0)  # digits 0-9

  # Count occurrences of each digit
  arr.each { |val| count[(val / exp) % 10] += 1 }

  # Cumulative count (positions)
  (1..9).each { |i| count[i] += count[i - 1] }

  # Build output array (iterate backwards for stability)
  (n - 1).downto(0) do |i|
    digit = (arr[i] / exp) % 10
    output[count[digit] - 1] = arr[i]
    count[digit] -= 1
  end

  output
end

pp radix_sort([170, 45, 75, 90, 802, 24, 2, 66])
# => [2, 24, 45, 66, 75, 90, 170, 802]

pp radix_sort([5, 3, 8, 1, 9, 2, 7, 4])
# => [1, 2, 3, 4, 5, 7, 8, 9]

pp radix_sort([])
# => []

# =============================================================================
# ASCII Animation — run: ruby sorts/radix_sort.rb --animate
# =============================================================================

if ARGV.include?("--animate")
  require_relative 'animation_player'

  player = AnimationPlayer.new
  arr = [170, 45, 75, 90, 802, 24, 2, 66]
  work = arr.dup
  max_val = work.max

  player.add_frame("RADIX SORT — Original array") do |o|
    work.each do |val|
      bar = "█" * (val / 10 + 1)
      o << "  \e[37m#{val.to_s.rjust(3)} #{bar}\e[0m\n"
    end
  end

  exp = 1
  place_names = ["ones", "tens", "hundreds", "thousands"]
  place_idx = 0

  while max_val / exp > 0
    place = place_names[place_idx] || "10^#{place_idx}"

    # Show which digit we're sorting by
    player.add_frame("Pass #{place_idx + 1}: Sort by #{place} digit") do |o|
      work.each do |val|
        digit = (val / exp) % 10
        digits_str = val.to_s
        bar = "█" * (val / 10 + 1)
        o << "  \e[37m#{val.to_s.rjust(3)} #{bar}  \e[33mdigit=#{digit}\e[0m\n"
      end
      o << "\n  Sorting by the #{place} digit (highlighted)\n"
    end

    # Show buckets
    buckets = Array.new(10) { [] }
    work.each { |val| buckets[(val / exp) % 10] << val }

    player.add_frame("Pass #{place_idx + 1}: Elements placed into digit buckets") do |o|
      (0..9).each do |d|
        next if buckets[d].empty?
        o << "  \e[36mBucket #{d}: #{buckets[d].inspect}\e[0m\n"
      end
    end

    work = counting_sort_by_digit(work, exp)

    player.add_frame("Pass #{place_idx + 1}: After sorting by #{place}") do |o|
      work.each do |val|
        bar = "█" * (val / 10 + 1)
        o << "  \e[32m#{val.to_s.rjust(3)} #{bar}\e[0m\n"
      end
      o << "\n  Array: #{work.inspect}\n"
    end

    exp *= 10
    place_idx += 1
  end

  player.add_frame("RADIX SORT — Sorted! No element-to-element comparisons.") do |o|
    work.each do |val|
      bar = "█" * (val / 10 + 1)
      o << "  \e[32m#{val.to_s.rjust(3)} #{bar}\e[0m\n"
    end
  end

  player.play
end
