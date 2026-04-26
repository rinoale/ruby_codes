# Sorting Algorithms Reference

All animations: `ruby sorts/<file> --animate` — navigate with ← → arrow keys.

## Overview

| Algorithm | Time (avg) | Time (worst) | Time (best) | Space | Stable | Type |
|---|---|---|---|---|---|---|
| Bubble Sort | O(n²) | O(n²) | O(n) | O(1) | Yes | Comparison |
| Insertion Sort | O(n²) | O(n²) | O(n) | O(1) | Yes | Comparison |
| Selection Sort | O(n²) | O(n²) | O(n²) | O(1) | No | Comparison |
| Merge Sort | O(n log n) | O(n log n) | O(n log n) | O(n) | Yes | Comparison |
| Quick Sort | O(n log n) | O(n²) | O(n log n) | O(log n) | No | Comparison |
| Heap Sort | O(n log n) | O(n log n) | O(n log n) | O(1) | No | Comparison |
| Tim Sort | O(n log n) | O(n log n) | O(n) | O(n) | Yes | Hybrid |
| Counting Sort | O(n + k) | O(n + k) | O(n + k) | O(k) | Yes | Non-comparison |
| Radix Sort | O(d × n) | O(d × n) | O(d × n) | O(n + k) | Yes | Non-comparison |
| Bucket Sort | O(n) | O(n²) | O(n) | O(n + k) | Depends | Non-comparison |

n = number of elements, k = range of values, d = number of digits

## Comparison-Based Sorts

These sorts work by comparing elements. The theoretical lower bound for comparison sorts is O(n log n).

### Bubble Sort — `bubble_sort.rb`

Repeatedly swap adjacent elements if they're in the wrong order. Largest elements "bubble up" to the end each pass.

**Pros:**
- Simplest sort to understand and implement
- O(n) on already-sorted data (with early stop optimization)
- Stable
- In-place (O(1) memory)

**Cons:**
- O(n²) — too slow for anything beyond tiny arrays
- Even among O(n²) sorts, it's the slowest in practice

**When to use:** Teaching and learning only. Never in production.

---

### Insertion Sort — `insertion_sort.rb`

Pick the next unsorted element, insert it into its correct position in the sorted region. Like sorting playing cards in your hand.

**Pros:**
- O(n) on nearly-sorted data — each element moves very little
- Low overhead — no recursion, no extra allocations
- Fastest sort for small arrays (<32 elements) due to minimal overhead
- Stable
- In-place
- Online — can sort as data arrives

**Cons:**
- O(n²) on random/reverse data

**When to use:**
- Small arrays (Tim sort uses it for chunks under 32)
- Nearly-sorted data
- When simplicity matters and array is small

---

### Selection Sort — `selection_sort.rb`

Scan unsorted region to find the minimum, swap it into the next sorted position.

**Pros:**
- Exactly n-1 swaps (minimum possible) — good when writes are expensive
- Simple to understand

**Cons:**
- Always O(n²) — no best-case optimization
- Not stable
- Insertion sort beats it in virtually every scenario

**When to use:** When minimizing the number of swaps matters (e.g., writing to flash memory where writes are costly). Otherwise, use insertion sort.

---

### Merge Sort — `merge_sort.rb`

Divide array in half recursively, then merge sorted halves back together.

**Pros:**
- Guaranteed O(n log n) — no worst-case degradation
- Stable
- Excellent for linked lists (merge is O(1) extra space)
- Excellent for external sorting (data on disk that doesn't fit in memory)
- Parallelizable — left and right halves can be sorted independently

**Cons:**
- O(n) extra memory for the merge step
- Slower than quicksort in practice on random data (more overhead)

**When to use:**
- Need guaranteed performance (no O(n²) risk)
- Need stability
- Sorting linked lists
- External sorting (files too large for memory)

---

### Quick Sort — `quick_sort.rb`

Pick a pivot, partition array into elements less/equal/greater than pivot, recurse.

**Pros:**
- Fastest comparison sort in practice on random data
- Good cache locality (sequential memory access)
- In-place version uses only O(log n) stack space

**Cons:**
- O(n²) worst case with bad pivot (already-sorted data + first-element pivot)
- Not stable
- Performance depends heavily on pivot selection

**When to use:**
- General-purpose in-memory sorting
- When average-case speed matters more than worst-case guarantee
- C++ std::sort uses this (introsort variant)

**Pivot strategies:**
- Random pivot: avoids worst case on most inputs
- Median-of-three: pick median of first, middle, last element
- Introsort: start with quicksort, switch to heapsort if recursion gets too deep

---

### Heap Sort — `heap_sort.rb`

Build a max-heap (parent >= children), then repeatedly extract the maximum.

**Pros:**
- Guaranteed O(n log n)
- In-place — O(1) extra memory (only sort with both guarantees)
- Good for finding top-K elements (just extract K times)

**Cons:**
- Poor cache locality — jumps around in memory (parent/child indexing)
- Not stable
- Slower than quicksort in practice despite same Big-O
- More complex to implement than merge sort

**When to use:**
- Need guaranteed O(n log n) AND O(1) memory
- Priority queues
- Finding top K elements from a large dataset
- When you can't afford O(n) extra memory for merge sort

---

### Tim Sort — `tim_sort.rb`

Hybrid of insertion sort (for small chunks) + merge sort (for combining).
Finds naturally sorted "runs" in the data and merges them.

**Pros:**
- O(n) on already-sorted or nearly-sorted data
- Guaranteed O(n log n) worst case
- Stable
- Exploits real-world data patterns (partially sorted runs)
- Default sort in Ruby, Python, Java, JavaScript

**Cons:**
- O(n) extra memory
- Complex to implement correctly
- Overkill for tiny arrays (but falls back to insertion sort for those)

**When to use:** This is the default — it's what Ruby's `.sort` uses. Best all-around sort for real-world data. You rarely need to implement it yourself; just know why it's the default.

---

## Non-Comparison Sorts

These sorts don't compare elements to each other. They exploit the structure of the data (integers, digit positions, value ranges) to sort in O(n). They break the O(n log n) lower bound that applies to comparison sorts.

### Counting Sort — `counting_sort.rb`

Count occurrences of each value, then rebuild the array from counts.

**Pros:**
- O(n + k) — faster than any comparison sort when k is small
- Stable
- Simple to implement
- Used as a subroutine in radix sort

**Cons:**
- Only works on integers (or data mappable to small integers)
- O(k) memory — wastes space when range k is large
- Useless when k >> n (e.g., sorting 10 numbers in range 0..1,000,000)

**When to use:**
- Integer data with a small, known range (ages, scores, grades, ASCII values)
- As building block for radix sort

---

### Radix Sort — `radix_sort.rb`

Sort digit by digit (least significant to most significant), using counting sort for each digit.

**Pros:**
- O(d × n) where d = number of digits — effectively O(n) for fixed-width integers
- Stable
- No element-to-element comparisons
- Excellent for fixed-length keys (IDs, phone numbers, IP addresses)

**Cons:**
- Only works on integers or fixed-length strings
- Needs stable subroutine sort (counting sort)
- Not adaptive — same cost regardless of data order
- Tricky with negative numbers (need offset)

**When to use:**
- Large arrays of integers with bounded digit count
- Sorting fixed-length strings (lexicographic order)
- When d (digits) << log(n), radix beats comparison sorts

---

### Bucket Sort — `bucket_sort.rb`

Distribute elements into range-based buckets, sort each bucket, concatenate.

**Pros:**
- O(n) average when data is uniformly distributed
- Conceptually simple
- Can use any sort for individual buckets

**Cons:**
- O(n²) worst case when all elements land in one bucket
- Requires knowledge of data distribution and range
- Extra memory for buckets

**When to use:**
- Uniformly distributed data with known bounds (random floats 0.0-1.0)
- When you can guarantee even distribution across buckets

---

## Decision Guide

```
Need to sort?
│
├─ Small array (<32 elements)?
│  └─ Insertion sort
│
├─ Data is integers with small range?
│  └─ Counting sort
│
├─ Data is integers with fixed digit count?
│  └─ Radix sort
│
├─ Data is uniformly distributed with known bounds?
│  └─ Bucket sort
│
├─ Need stability?
│  ├─ Need guaranteed O(n log n)?
│  │  └─ Merge sort (or Tim sort)
│  └─ General purpose?
│     └─ Tim sort (Ruby's default)
│
├─ Need O(1) extra memory?
│  ├─ Need guaranteed O(n log n)?
│  │  └─ Heap sort
│  └─ Accept O(n²) worst case?
│     └─ Quick sort (in-place)
│
└─ General purpose, maximum speed?
   └─ Tim sort / Quick sort
```
