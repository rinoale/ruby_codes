# Bucket vs Counting Sort

## Q: I used arrays with unused slots for sorting. Is this common for counting sort?

Yes — allocating an array sized by the value range is exactly how counting sort works in every language. The unused slots are the tradeoff: you waste memory to gain O(n) time.

In C++/Java you'd declare `int counts[max_val + 1]` and it's the same idea — most slots may be zero, but you get O(1) access by index.

Ruby just hides the allocation. When you do `count_arr[100] = 1` on an empty array, Ruby silently fills indices 0-99 with `nil`. Same memory cost, just automatic.

The strategy works when the value range is small relative to the data size. The quiz: 5 million elements but only values 1-100, so 100 slots is trivial. If values ranged 0 to 1 billion, you'd need a billion-slot array for maybe 100 elements — that's when this strategy breaks and you use a hash instead.

---

## Q: So counting sort is advantageous when there are many duplicated entries?

In practice, yes. Many duplicates and small range go together. A wide range with many duplicates is rare in real data.

"Counting sort is good when there are many duplicates" is a practical, correct heuristic. The textbook says "when k is small relative to n" but that's the formal way of saying the same thing.

It always comes back to **k relative to n**:
- k << n → counting sort wins
- k ≈ n → either works
- k >> n → comparison sort wins

(k = value range, n = number of elements)

The **pigeonhole principle** confirms this: n items into k slots means when n >> k, duplicates are mathematically guaranteed.

---

## Q: Which sorts did I use in the quiz solution?

Two non-comparison sorts combined:

1. **Bucket sort** — `count_arr[frequency] << value` groups elements by frequency into buckets
2. **Counting sort** — `custom_sort` orders the final result by value using an index-based array

In v2, the counting sort was simplified to `result_buckets[val] = true` — same idea (index = value, iterate by index for free ordering), since each value appears at most once in the result.

---

## Q: The bucket code isn't actually sorting, is it?

```ruby
count_map.each do |i, count|
  count_arr[count] ||= []
  count_arr[count] << i
end
```

Right — it's not sorting in the traditional sense. It uses the bucket sort **technique** (distribute by index) but for grouping by frequency, not sorting by value.

---

## Q: What's the difference between bucket sort and counting sort?

**Counting sort** — each index holds a **count** (how many of this value). Rebuild by repeating each index by its count.

```
values:  [3, 1, 3, 2]
index:    0  1  2  3
counts:  [0, 1, 1, 2]    ← "one 1, one 2, two 3s"
output:  [1, 2, 3, 3]
```

**Bucket sort** — each index holds a **list of elements** that fall into that range. Sort each bucket, concatenate.

```
values:  [35, 12, 48, 3]
bucket 0 [0-19]:  [12, 3]
bucket 1 [20-39]: [35]
bucket 2 [40-59]: [48]
sort each → concat → [3, 12, 35, 48]
```

Key difference: counting sort counts and reconstructs. Bucket sort collects and sub-sorts.

---

## Q: So bucket sort is: split range into pieces, distribute, sort each bucket, combine?

Exactly. And the key difference in the quiz solution: the bucket index meant "frequency" instead of "value range", and there was no need to sort inside each bucket — just pick elements from highest frequency buckets down.

Same data structure, different purpose. It can also be said: a sort by frequency using buckets. The bucket index *is* the frequency, so higher index = higher frequency. Walking backwards gives most frequent first.
