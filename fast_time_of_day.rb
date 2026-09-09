# Ruby demonstration of "Fast Time of Day" (https://www.benjoffe.com/fast-time-of-day)
#
# The article converts seconds-of-day into hour/minute/second using two
# fixed-point multiplications instead of a chain of divisions.  The C code
# relies on fixed-width integers (u32/u64) and wraparound; Ruby Integers are
# arbitrary precision, so `(u64) x * K >> 32` is simply `x * K >> 32`, and
# u32 truncation is emulated explicitly with `& U32`.
#
# Ruby cannot show the CPU-cycle latency win (each Integer op is a VM
# instruction), but it can exhaustively verify every formula and confirm the
# article's claimed valid input ranges are exact.

U32 = 0xFFFF_FFFF

M_MUL = (1 << 32) / 60   + 1   # 71582789
H_MUL = (1 << 32) / 3600 + 1   # 1193047
raise "constant mismatch" unless M_MUL == 71_582_789 && H_MUL == 1_193_047

# ---------------------------------------------------------------- reference
def naive(t)
  h, rem = t.divmod(3600)
  m, s   = rem.divmod(60)
  [h, m, s]
end

# ----------------------------------------------- V1: broken dependency chain
def v1(t)
  tmin   = t * M_MUL >> 32
  hour   = t * H_MUL >> 32
  second = t - tmin * 60
  minute = tmin - hour * 60
  [hour, minute, second]
end

# ---------------------------------------------- V2: fixed-point hi/low bits
# The low 32 bits of the product are the fractional position inside the unit;
# multiplying that fraction by 60 and taking the integer part gives the digit.
def v2(t)
  hprd   = t * H_MUL
  mlow   = (t * M_MUL) & U32       # u32 wraparound keeps only the fraction
  hlow   = hprd & U32
  hour   = hprd >> 32
  minute = hlow * 60 >> 32
  second = mlow * 60 >> 32
  [hour, minute, second]
end

# -------------------------------------------------- V3: base-64 clock trick
# x mod D == (x + c*floor(x/D)) mod (D+c); with D=60, c=4 the modulus is 64,
# so `% 64` becomes `& 63`.
def v3(t)
  tmin   = t * M_MUL >> 32
  hour   = t * H_MUL >> 32
  second = (t + 4 * tmin) & 63
  minute = (tmin + 4 * hour) & 63
  [hour, minute, second]
end

# ---------------------------------------------- leap second hack (0..86400)
# Round-down multipliers plus a pre-increment put the fixed-point error exactly
# at t == 86400, which then yields 23:59:60 with no branch.
def leap_hack(t)
  tinc   = t + 1
  tmin   = tinc * 143_163_919 >> 33
  hour   = tinc * 2_386_065   >> 33
  second = (t + tmin * 4) % 64
  minute = (tmin + hour * 4) % 64
  [hour, minute, second]
end

# -------------------------------------------------- ARM NEON 32-bit variant
def neon(t)
  hour = t * 37_283 >> 27
  tsec = t - hour * 3600
  mins = tsec * 2185 >> 17
  secs = tsec - mins * 60
  [hour, mins, secs]
end

# ------------------------------------------------ millisecond timestamps
def naive_ms(t)
  h, rem  = t.divmod(3_600_000)
  m, rem  = rem.divmod(60_000)
  s, ms   = rem.divmod(1000)
  [h, m, s, ms]
end

def fast_ms(t)
  tsec   = t * 274_877_907   >> 38
  tmin   = t * 1_172_812_403 >> 46
  hour   = t * 2_501_999_793 >> 53
  milli  = t - tsec * 1000
  second = tsec - tmin * 60
  minute = tmin - hour * 60
  [hour, minute, second, milli]
end

# ------------------------------------------------------------- verification
def verify(name, range, ref: method(:naive), probe: 500_000)
  bad = range.find { |t| send(name, t) != ref.call(t) }
  status = bad ? "FAIL at #{bad}" : "OK"
  # Is the claimed upper bound tight?  Look for the first failure past it.
  first_bad = (range.max + 1..range.max + probe).find { |t| send(name, t) != ref.call(t) }
  tight = first_bad == range.max + 1 ? "tight" : "first failure at #{first_bad.inspect}"
  hms = send(name, range.max).map { |x| x.to_s.rjust(2, "0") }.join(":")
  printf "%-10s 0..%-8d %-4s  max -> %s  (bound %s)\n", name, range.max, status, hms, tight
end

puts "== exhaustive verification against divmod =="
verify(:v1,        0..2_257_198)
verify(:v2,        0..2_255_818)
verify(:v3,        0..2_257_198)
verify(:neon,      0..115_199)

# Leap hack: 0..86399 must match, and 86400 must be 23:59:60.
leap_ok = (0..86_399).all? { |t| leap_hack(t) == naive(t) }
puts "leap_hack  0..86399   #{leap_ok ? 'OK' : 'FAIL'}   86400 -> #{leap_hack(86_400).inspect}"
# Show that plain V3 does NOT handle the leap second (it would need a branch).
puts "           (plain v3 at 86400 -> #{v3(86_400).inspect}, i.e. 24:00:00)"

# Milliseconds: full u32 range is 4.3e9 inputs, too many for Ruby; check the
# edges of every unit boundary plus a random sample.
edges = []
(0..(U32 / 3_600_000)).each { |h| edges << h * 3_600_000 }          # every hour boundary
[1000, 60_000].each { |u| (0..2_000).each { |k| edges << k * u - 1 << k * u } }
edges << U32
srand(1)
sample = Array.new(1_000_000) { rand(0..U32) }
ms_ok = (edges + sample).all? { |t| t <= U32 && fast_ms(t) == naive_ms(t) }
puts "fast_ms    u32 (#{edges.size} boundaries + 1e6 random)  #{ms_ok ? 'OK' : 'FAIL'}"

# ---------------------------------------------------------------- benchmark
require "benchmark"
N = 500_000
inputs = Array.new(N) { rand(0..86_399) }
puts "\n== rough Ruby benchmark, #{N} conversions (not the article's point, but for interest) =="
Benchmark.bm(10) do |x|
  %i[naive v1 v2 v3 neon].each do |m|
    x.report(m.to_s) { inputs.each { |t| send(m, t) } }
  end
end
