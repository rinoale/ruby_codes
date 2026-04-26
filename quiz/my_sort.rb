# Advanced #13: Implement Array#my_sort
# 
# Implement a sorting method without using any built-in sort. Must meet a target time complexity.
# 
# Requirements:
# 
# - Array#my_sort — returns a new sorted array (ascending)
# - Array#my_sort { |a, b| ... } — accepts an optional comparison block (like Ruby's sort)
# - When block given: negative means a < b, 0 means equal, positive means a > b
# - Time complexity: O(n log n) — O(n²) sorts (bubble, selection, insertion) will fail the performance test
# - Do not use Ruby's built-in sort, sort_by, min, max, or minmax
# 
# Example:

class Array
  def my_sort
  end
end

[5, 3, 8, 1, 9, 2].my_sort
# => [1, 2, 3, 5, 8, 9]

["banana", "apple", "cherry"].my_sort
# => ["apple", "banana", "cherry"]

# Custom comparator — sort by string length
["fig", "banana", "kiwi", "apple"].my_sort { |a, b| a.length - b.length }
# => ["fig", "kiwi", "apple", "banana"]

# Descending order
[5, 3, 8, 1].my_sort { |a, b| b <=> a }
# => [8, 5, 3, 1]

[].my_sort
# => []

# Performance test — must complete under 2 seconds:

large = (1..200_000).to_a.shuffle
large.my_sort

# Hint: merge sort is the most straightforward O(n log n) sort to implement.
