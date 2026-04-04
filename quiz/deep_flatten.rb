# Note: default mutable argument (result = []) is safe here because Ruby creates
# a new array on each top-level call. However, it exposes an internal accumulator
# to the caller — consider making it a private parameter or using a wrapper method
# to prevent misuse like deep_flatten([1,2], existing_array).
#
# Also, very deeply nested arrays could hit Ruby's stack limit since this is recursive.
# An iterative approach with an explicit stack would avoid that.
def deep_flatten(arr, result = [])
  arr.each do |e|
    if e.is_a? Array
      deep_flatten(e, result)
    else
      result << e
    end
  end

  result
end

pp deep_flatten([1, [2, [3, 4], 5], [6, [7, [8]]]])
