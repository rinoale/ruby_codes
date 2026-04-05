class Btree
  def initialize
    @tree = {}
  end

  def insert(i, cursor = @tree.first&.[](1))
    if cursor.nil?
      @tree[i] = { value: i }
    else
      return if cursor[:value] == i

      if i > cursor[:value]
        if cursor[:next].nil?
          cursor[:next] = i
          @tree[i] = { value: i }
        else
          insert(i, @tree[cursor[:next]])
        end
      else
        if cursor[:previous].nil?
          cursor[:previous] = i
          @tree[i] = { value: i }
        else
          insert(i, @tree[cursor[:previous]])
        end
      end
    end
  end

  # In-order traversal using an explicit stack.
  # Visits every node exactly once in sorted (ascending) order.
  #
  # Given this tree:
  #
  #         7
  #        / \
  #       1   9
  #        \    \
  #         3    15
  #        / \     \
  #       2   5    18
  #
  # Step    Action              Stack           Result
  # ────    ──────              ─────           ──────
  #  1      Go left from 7      [7, 1]
  #  2      1 has no left        [7, 1]
  #  3      Pop 1                [7]            [1]
  #  4      Go right to 3        [7, 3]
  #  5      Go left to 2         [7, 3, 2]
  #  6      Pop 2                [7, 3]         [1, 2]
  #  7      2 has no right
  #  8      Pop 3                [7]            [1, 2, 3]
  #  9      Go right to 5        [7, 5]
  # 10      Pop 5                [7]            [1, 2, 3, 5]
  # 11      Pop 7                []             [1, 2, 3, 5, 7]
  # 12      Go right to 9        [9]
  # 13      Pop 9                []             [..., 7, 9]
  # 14      Go right to 15       [15]
  # 15      Pop 15               []             [..., 9, 15]
  # 16      Go right to 18       [18]
  # 17      Pop 18               []             [..., 15, 18]
  #
  # Always: go left as far as possible → pop → go right → repeat.
  def to_a
    result = []
    stack = []
    cursor = @tree.first&.[](1)  # start at root

    while cursor || !stack.empty?
      # 1. Go as far left as possible, pushing each node onto the stack
      while cursor
        stack.push(cursor)
        cursor = cursor[:previous] ? @tree[cursor[:previous]] : nil
      end

      # 2. Pop the leftmost unvisited node, add its value
      cursor = stack.pop
      result << cursor[:value]

      # 3. Move to the right child (if any) and repeat
      cursor = cursor[:next] ? @tree[cursor[:next]] : nil
    end

    result
  end

  # Recursive in-order traversal — simplest approach.
  # The call stack acts as the "footprint" automatically.
  # When a recursive call returns, you're back at the parent — no stack or
  # parent pointer needed.
  #
  # For each node: traverse left subtree → visit node → traverse right subtree
  #
  #         7
  #        / \
  #       1   9          to_array(7)
  #        \    \         = to_array(1) + [7] + to_array(9)
  #         3    15       = ([] + [1] + to_array(3)) + [7] + ([] + [9] + to_array(15))
  #        / \     \      = ... eventually unrolls to [1,2,3,5,7,9,15,18]
  #       2   5    18
  def to_array(cursor = @tree.first&.[](1))
    return [] if cursor.nil?

    to_array(@tree[cursor[:previous]]) + [cursor[:value]] + to_array(@tree[cursor[:next]])
  end

  def far_next(cursor = @tree.first&.[](1))
    cursor[:previous].nil? ? cursor[:value] : far_next(@tree[cursor[:previous]])
  end
end

# Node-based BST — cleaner traversal because nodes link directly to children
class Btree2
  Node = Struct.new(:value, :left, :right)

  def initialize
    @root = nil
  end

  def insert(val, node = @root)
    if @root.nil?
      @root = Node.new(val)
      return
    end

    return if node.value == val

    if val < node.value
      node.left.nil? ? node.left = Node.new(val) : insert(val, node.left)
    else
      node.right.nil? ? node.right = Node.new(val) : insert(val, node.right)
    end
  end

  # The clean recursive form — no Hash lookups, just node.left / node.right
  def to_a(node = @root)
    return [] if node.nil?
    to_a(node.left) + [node.value] + to_a(node.right)
  end
end

# === Compare both implementations ===

btree2 = Btree2.new
[7, 1, 1, 3, 2, 5, 9, 15, 18].each { |i| btree2.insert(i) }
puts "\nBtree2 (Node-based):"
pp btree2.to_a

btree = Btree.new

btree.insert(7)
btree.insert(1)
btree.insert(1)
btree.insert(3)
btree.insert(2)
btree.insert(5)
btree.insert(9)
btree.insert(15)
btree.insert(18)
puts btree.instance_variable_get(:@tree)
puts btree.far_next
pp btree.to_a
pp btree.to_array
