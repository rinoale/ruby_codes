# Advanced #16: Longest Substring Without Repeating Characters
# 
# Given a string, find the length of the longest substring that contains no repeating characters.
# 
# Requirements:
# 
# - longest_unique_substring(str) — returns the length of the longest substring with all unique characters
# - Time complexity: O(n) — brute-force checking all substrings (O(n³)) or even O(n²) will fail the performance test
# - Do not use sort, sort_by
# 
# Example:

def longest_unique_substring(str)
  seen_map = {}
  best = ''
  left = 0
  right = 0

  str.split('').each_with_index do |char, i|
    right = i

    if !seen_map[char].nil?
      best = str[left..right - 1] if right - left > best.length - 1
      new_left = seen_map[char] + 1
      left = new_left if new_left > left
    end

    seen_map[char] = i
  end

  best = str[left..right] if right - left > best.length  - 1
  [best.length, best]
end

# Cleanest version:
# - Track length only, no substring slicing
# - each_char instead of split('') — no intermediate array
# - seen[char] >= left combines nil check + forward-only check
# - Update best every step — no post-loop fixup needed
def longest_unique_clean(str)
  seen = {}
  left = 0
  best = 0

  str.each_char.with_index do |char, right|
    if seen[char] && seen[char] >= left
      left = seen[char] + 1
    end

    seen[char] = right
    length = right - left + 1
    best = length if length > best
  end

  best
end

pp longest_unique_substring("abcabcbb")
# => 3  ("abc")

pp longest_unique_substring("bbbbb")
# => 1  ("b")

pp longest_unique_substring("pwwkew")
# => 3  ("wke")

pp longest_unique_substring("")
# => 0

pp longest_unique_substring("abcdef")
# => 6  (entire string)

pp longest_unique_substring("dvdf")
# => 3  ("vdf")

# Performance test — must complete under 1 second:

large = (1..1_000_000).map { ('a'..'z').to_a.sample }.join
longest_unique_substring(large)

# Hint: This is a classic sliding window problem — but unlike the fixed window in the previous quiz, this window grows and shrinks dynamically.
