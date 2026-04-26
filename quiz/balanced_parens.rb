# Advanced #17: Balanced Parentheses Generator
# 
# Given a number n, generate all valid combinations of n pairs of parentheses.
# 
# Requirements:
# 
# - generate_parens(n) — returns an array of all valid combinations
# - Each combination is a string of length 2n
# - Results must be in lexicographic order
# - Must generate only valid combinations — no filtering invalid ones after the fact
# - Time complexity: O(4^n / √n) — this is the Catalan number, which is the count of valid combinations
# 
# Example:

def generate_parens(num)
  binary_format = "%0#{num * 2}b"
  binary_str = binary_string(num)

  result = []
  while true do
    break if binary_str[0] != '1'

    if binary_str.count('1') == num
      detect_contradict = 0
      binary_str.split('').each do |char|
        detect_contradict += char == '1' ? 1 : -1
        break if detect_contradict < 0
      end

      result << binary_str unless detect_contradict < 0
    end

    binary_str = (binary_format % (binary_str.to_i(2) - 1))
  end

  result.map { |e| draw_parens(e)  }
end

def draw_parens(binary_str)
  binary_str.gsub("1", "(").gsub("0", ")")
end

def binary_string(num)
  "1" * num + "0" * num 
end

# Correct answer — recursive approach.
# At each step, decide to add ( or ), only if it keeps the string valid.
# Never builds an invalid combination — every branch is guaranteed valid.
#
#   build("", 0, 0)
#   ├─ build("(", 1, 0)
#   │  ├─ build("((", 2, 0)
#   │  │  └─ build("(()", 2, 1)
#   │  │     └─ build("(())", 2, 2) ✓
#   │  └─ build("()", 1, 1)
#   │     └─ build("()(", 2, 1)
#   │        └─ build("()()", 2, 2) ✓
#
# Two rules:
#   Add ( if open < n — still have opens to use
#   Add ) if close < open — won't create an invalid prefix
def generate_parens_recursive(n)
  result = []
  build(result, "", 0, 0, n)
  result
end

def build(result, current, open, close, n)
  if current.length == 2 * n
    result << current
    return
  end

  build(result, current + "(", open + 1, close, n) if open < n
  build(result, current + ")", open, close + 1, n) if close < open
end

pp generate_parens_recursive(0)
pp generate_parens_recursive(1)
pp generate_parens_recursive(2)
pp generate_parens_recursive(3)
pp generate_parens_recursive(4).length

pp generate_parens(0)
# => [""]

pp generate_parens(1)
# => ["()"]

pp generate_parens(2)
# => ["(())", "()()"]

pp generate_parens(3)
# => ["((()))", "(()())", "(())()", "()(())", "()()()"]

pp generate_parens(4).length
# => 14

# Rules for validity:
# - Every ( must have a matching )
# - At any point reading left to right, the count of ( must be >= count of )
# - Total ( count must equal total ) count must equal n
