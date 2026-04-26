# Advanced #15: Matrix Spiral
# 
# Given an m x n matrix (2D array), return all elements in spiral order — starting from the top-left, going right, then down, then left, then up, and repeating inward.
# 
# Requirements:
# 
# - spiral_order(matrix) — returns a flat array of elements in spiral order
# - Must work with rectangular matrices (not just square)
# - Must handle single row, single column, and empty matrix
# - Time complexity: O(m × n) — visit each element exactly once
# 
# Example:


# Review:
# - Direction vector + rotation on boundary detection is a clean approach.
# - Lambdas as closures eliminate parameter passing — next_step and should_turn
#   capture mutable state (x, y, current_vector, seen_coordinates) from the
#   enclosing scope. This is the key difference between lambdas and methods in Ruby:
#   def starts fresh scope, lambdas/procs capture surrounding scope.
# - Using 1.upto(x_range * y_range) guarantees exactly m×n visits — O(m×n).
def spiral_order(arr)
  # constants
  x_range = arr.first&.length || 0
  y_range = arr.length || 0
  vector_rotation = [[1, 0], [0, 1], [-1, 0], [0, -1]]

  # mutable variables
  seen_coordinates = {}
  result = []
  x, y = [0, 0]
  current_vector = 0

  next_step = -> do
    [x + vector_rotation[current_vector % vector_rotation.length][0], y + vector_rotation[current_vector % vector_rotation.length][1]]
  end

  should_turn = -> do
    next_x, next_y = next_step.call
    !((0..(x_range - 1)).cover?(next_x) && (0..(y_range - 1)).cover?(next_y)) || seen_coordinates[[next_x, next_y]]
  end


  1.upto(x_range * y_range) do |i|
    result << arr[y][x]
    seen_coordinates[[x, y]] = true

    current_vector += 1 if should_turn.call
    x, y = next_step.call
  end
  result
end

# def next_step(x, y, cv, vector_rotation)
#   [x + vector_rotation[cv % vector_rotation.length][0], y + vector_rotation[cv % vector_rotation.length][1]]
# end
# 
# def turn?(x, y, cv, vector_rotation, x_range, y_range, seen_coordinates)
#   next_x, next_y = next_step(x, y, cv, vector_rotation)
#   !((0..(x_range - 1)).cover?(next_x) && (0..(y_range - 1)).cover?(next_y)) || seen_coordinates[[next_x, next_y]]
# end

pp spiral_order([
  [1,  2,  3,  4],
  [5,  6,  7,  8],
  [9, 10, 11, 12]
])
# => [1, 2, 3, 4, 8, 12, 11, 10, 9, 5, 6, 7]
#
# Visually:
#  → → → ↓
#  ↑ → → ↓
#  ↑ ← ← ←

pp spiral_order([
  [1, 2, 3],
  [4, 5, 6],
  [7, 8, 9]
])
# => [1, 2, 3, 6, 9, 8, 7, 4, 5]

pp spiral_order([[1, 2, 3]])
# => [1, 2, 3]

pp spiral_order([[1], [2], [3]])
# => [1, 2, 3]

spiral_order([])
# => []
