# Advanced #14: Sliding Window Maximum
# 
# Given an array of integers and a window size k, return the maximum value in each window as it slides from left to right.
# 
# Requirements:
# 
# - sliding_max(nums, k) — returns an array of maximums for each window position
# - Window slides one element at a time, left to right
# - Time complexity: O(n) — checking all k elements per window (O(n*k)) will fail the performance test
# - Do not use max, min, sort, sort_by
# 
# Example:

# Textbook O(n) approach using a deque (double-ended queue).
# Each element enters and leaves the deque at most once → O(n) guaranteed.
# No sub-array slicing needed — only indices are tracked.
#
# The deque is a "line of succession" — a pre-sorted chain of candidates.
# Front = current max. When it expires (leaves window), the next one
# steps up immediately — O(1) instead of rescanning O(k).
#
# Key rule: a new element pops ALL smaller elements from the back.
# They can never win — the new element is both NEWER (stays longer)
# and BIGGER. They're permanently eliminated.
#
#   deque: [9, 5, 3]    new element: 7
#
#   3 < 7 → pop 3  (7 is newer AND bigger — 3 can never win)
#   5 < 7 → pop 5  (same reason)
#   9 > 7 → stop
#
#   deque: [9, 7]       → 9 is current max, 7 is next in line
#
# Deque length varies:
#
#   Descending [9,8,7,6] k=4 → deque grows to k (nothing gets popped)
#     step 0: deque=[9]
#     step 1: deque=[9, 8]
#     step 2: deque=[9, 8, 7]
#     step 3: deque=[9, 8, 7, 6]   ← max length = k
#
#   Ascending [1,2,3,4] k=4 → deque stays at 1 (every newcomer pops all)
#     step 0: deque=[1]
#     step 1: deque=[2]     (1 popped)
#     step 2: deque=[3]     (2 popped)
#     step 3: deque=[4]     (3 popped)
#
# Performance comparison (500k elements, window=1000):
#
#   Input        Your version    Deque version
#   Shuffled     0.111s          0.084s        ← similar
#   Descending   17.455s         0.064s        ← 270x faster
#
# Your version only tracks a single winner. When it expires, it rescans
# the whole window. The deque always has the next-in-line ready.
def sliding_max_deque(arr, k)
  deque = []    # stores indices; arr[deque] values are always decreasing
  result = []

  arr.each_with_index do |val, i|
    # Remove index from front if it's outside the window
    deque.shift if deque.first && deque.first <= i - k

    # Remove from back: elements smaller than val can never be the max
    # (val is newer AND bigger — they're permanently eliminated)
    deque.pop while deque.any? && arr[deque.last] <= val

    # Add current index
    deque << i

    # Window is full (i >= k-1), front of deque is always the max
    result << arr[deque.first] if i >= k - 1
  end

  result
end

# Your approach — track winner and their "term" (slides until they leave)
def sliding_max(arr, window_size)
  result = []

  current_winner = nil
  term_of_winner = nil

  0.upto(arr.length - window_size).each do |i|
    window = i..(i + window_size - 1) 

    current_winner, term_of_winner = elect_winner(arr[window]) if current_winner.nil? || term_of_winner <= 0

    if arr[window].last > current_winner
      current_winner = arr[window].last
      term_of_winner = window_size
    end

    term_of_winner -= 1
    result << current_winner
  end

  result
end

def elect_winner(arr)
  winner = nil
  term = nil
  arr.each_with_index do |e, i|
    if winner.nil? || e > winner
      winner = e 
      term = i
    end
  end

  [winner, term]
end

pp sliding_max([1, 3, -1, -3, 5, 3, 6, 7], 3)
pp sliding_max_deque([1, 3, -1, -3, 5, 3, 6, 7], 3)
# Window positions:
# [1,  3, -1] -3  5  3  6  7  → max = 3
#  1 [3, -1, -3] 5  3  6  7  → max = 3
#  1  3 [-1, -3, 5] 3  6  7  → max = 5
#  1  3  -1 [-3, 5, 3] 6  7  → max = 5
#  1  3  -1  -3 [5, 3, 6] 7  → max = 6
#  1  3  -1  -3  5 [3, 6, 7] → max = 7
# => [3, 3, 5, 5, 6, 7]

pp sliding_max([9, 8, 7, 6, 5], 2)
pp sliding_max_deque([9, 8, 7, 6, 5], 2)
# => [9, 8, 7, 6]

pp sliding_max([1, 2, 3, 4, 5], 1)
pp sliding_max_deque([1, 2, 3, 4, 5], 1)
# => [1, 2, 3, 4, 5]

# Performance test — must complete under 1 second:

large = (1..500_000).to_a.shuffle
sliding_max(large, 1000)

# Hint: Think about a data structure where you can efficiently track what's the current maximum, and remove elements that can never be the maximum. A deque (double-ended queue) helps here.
