# Advanced #12: Two Sum Pairs
# 
# Given an array of integers and a target sum, find all unique pairs of numbers that add up to the target.
# 
# Requirements:
# 
# - find_pairs(nums, target) — returns an array of pairs [a, b] where a + b == target
# - Each pair sorted with the smaller number first: [a, b] where a <= b
# - Result sorted by the first element, then by the second
# - No duplicate pairs — [1, 4] should appear only once even if 1 or 4 appears multiple times
# - Time complexity: O(n). Brute-force O(n²) with nested loops will fail the performance test.
# 
# Example:

def find_pairs(arr, target)
  pair_map = {}
  result_arr = []
  arr.each do |i|
    pair = pair_map[i]
    if !pair.nil? && !pair[:seen]
      result_arr << (i > pair[:pair] ? [pair[:pair], i] : [i, pair[:pair]])
      pair[:seen] = true
    else
      pair_map[target - i] = { pair: i, seen: false }
    end
  end
  result_arr.sort
end

pp find_pairs([1, 2, 3, 4, 5, 6], 7)
# => [[1, 6], [2, 5], [3, 4]]

pp find_pairs([1, 1, 2, 2, 3, 3, 4, 4], 5)
# => [[1, 4], [2, 3]]

pp find_pairs([0, -1, 1, -2, 2], 0)
# => [[-2, 2], [-1, 1]]

pp find_pairs([], 5)
# => []

# Performance test — must complete under 1 second:

large = (1..500_000).to_a
find_pairs(large, 500_001)
# => [[1, 500000], [2, 499999], [3, 499998], ...]
