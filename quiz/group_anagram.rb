def group_anagrams(words)
  result = {}
  # Note: sort_by! mutates the caller's array. Consider sort_by (non-bang) to avoid side effects.
  words.sort_by!(&:downcase)
  words.each do |word|
    sorted_word = word.downcase.split('').sort
    result[sorted_word] ||= []
    result[sorted_word] << word
  end
  # Tip: could also use group_by for a more idiomatic approach:
  #   words.sort_by(&:downcase).group_by { |w| w.downcase.chars.sort }.values
  result.values.sort_by(&:first)
end

pp group_anagrams(["eat", "Tea", "tan", "ate", "nat", "bat"])
