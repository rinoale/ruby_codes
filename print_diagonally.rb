
arr_3_x_5 = [
  %w[a b c],
  %w[d e f],
  %w[g h i],
  %w[j k l],
  %w[m n o]
]

arr_5_x_3 = [
  %w[a b c d e],
  %w[f g h i j],
  %w[k l m n o]
]

def print_diagonally(input)
  max_rows_length = input.length
  max_columns_length = input.first.length
  new_max_rows_length = max_rows_length + max_columns_length - 1

  (0...new_max_rows_length).each do |i|
    coordinate = if max_rows_length <= i
                   [max_rows_length - 1, i - max_rows_length + 1]
                 else
                   [i, 0]
                 end

    puts "printing for row:#{i} with coordinate #{coordinate.to_s}"

    while(coordinate.first >= 0 && coordinate.last < max_columns_length) do
      puts input[coordinate.first][coordinate.last]
      coordinate[0] -= 1
      coordinate[1] += 1
    end
  end
end

print_diagonally(arr_3_x_5)
print_diagonally(arr_5_x_3)
