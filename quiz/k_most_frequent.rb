# Advanced #13: K Most Frequent Elements
# 
# Given an array of integers and a number k, return the k most frequently occurring elements.
# 
# Requirements:
# 
# - k_most_frequent(nums, k) — returns an array of the k most frequent elements
# - If there's a tie in frequency, the smaller number comes first
# - Time complexity: O(n) — sorting the frequency counts (O(n log n)) will fail the performance test
# - Do not use sort, sort_by, min, max, min_by, max_by, tally
# 
# Example:

def k_most_frequent(arr, target)
  count_map = {}
  count_arr = []
  arr.each do |i|
    count_map[i] ||= 0
    count_map[i] += 1
  end

  count_map.each do |i, count|
    count_arr[count] ||= []
    count_arr[count] << i
  end


  result = []
  count_arr.compact.reverse.each do |counted|
    counted.each do |i|
      result.unshift(i)
      break if result.length == target
    end
    break if result.length == target
  end
  custom_sort(result)
end

def custom_sort(arr, desc = false)
  result = []
  count_arr = []
  arr.each do |i|
    count_arr[i] ||= 0
    count_arr[i] += 1
  end

  count_arr.each_with_index do |e, i|
    next if e.nil?

    e.times { desc ? result.unshift(i) : result << i }
  end

  result
end

# Optimized version:
# - No compact.reverse (avoids creating new arrays)
# - No separate custom_sort step
# - Uses result_buckets indexed by value for free ascending order
def k_most_frequent_v2(arr, target)
  count_map = {}
  count_arr = []
  arr.each do |i|
    count_map[i] ||= 0
    count_map[i] += 1
  end

  count_map.each do |i, count|
    count_arr[count] ||= []
    count_arr[count] << i
  end

  # Walk count_arr backwards by index — no new array created
  result_buckets = []
  remaining = target

  (count_arr.length - 1).downto(0) do |freq|
    next if count_arr[freq].nil?

    count_arr[freq].each do |val|
      result_buckets[val] = true
      remaining -= 1
      break if remaining == 0
    end
    break if remaining == 0
  end

  # Iterating by index gives ascending order for free — no sort needed
  result = []
  result_buckets.each_with_index do |present, val|
    result << val if present
  end
  result
end

pp k_most_frequent([1, 1, 1, 2, 2, 3], 2)
# => [1, 2]

pp k_most_frequent([4, 4, 4, 2, 2, 2, 1, 1, 3], 3)
# => [1, 2, 4]  (1,2,4 all have freq 2+, but 4 has 3, 2 has 3, 1 has 2 — wait...)
# let me recalculate:
# 4 appears 3 times, 2 appears 3 times, 1 appears 2 times, 3 appears 1 time
# top 3: [2, 4, 1] → sorted by tie rule (smaller first): [2, 4, 1]
# => [2, 4] are freq 3, [1] is freq 2
# => [1, 2, 4]

k_most_frequent([1], 1)
# => [1]

# Performance test — must complete under 1 second:

large = (1..100).to_a.flat_map { |i| [i] * (100_001 - i) }
large.shuffle!
k_most_frequent(large, 10)
# => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

# Hint: there's a technique called "bucket sort by frequency" — think about what the maximum possible frequency is.
