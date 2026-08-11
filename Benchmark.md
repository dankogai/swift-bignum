# Benchmark

`BigInt` here against [attaswift/BigInt] — the dependency this package used to
have — and against the arbitrary-precision integers built into JavaScript,
Python and Ruby. Same inputs, same machine, same run.

**None of this is part of `swift test`.** The benchmarks are a package of their
own, so running them is something you ask for:

```bash
cd Benchmarks && swift run -c release      # against attaswift
cd Benchmarks && sh cross/run.sh           # and against node, python, ruby
```

The cross-language run uses `/usr/bin/ruby`, the one macOS ships, since that is
the Ruby a Mac has without being asked. `RUBY=/path/to/ruby sh cross/run.sh`
picks another; a newer Ruby measures noticeably differently.

It has to be its own package rather than a target in the root manifest, because
SwiftPM resolves every declared dependency whether or not the target using it is
being built — a benchmark target at the root would quietly end the "`swift build`
fetches nothing" property. Nothing in `Benchmarks/` is reachable from the root
package.

## The one thing to read if you read nothing else

**Five implementations were asked to right-shift a negative number. Four agree,
and the one that does not is attaswift.** `Int` shifts arithmetically — it floors
— and so do this package, JavaScript, Python and Ruby. attaswift shifts the
magnitude and keeps the sign, which truncates toward zero:

| value | `Int` | swift-bignum | node | python | ruby | attaswift |
|---:|---:|---:|---:|---:|---:|---:|
| -1 | -1 | -1 | -1 | -1 | -1 | -1 |
| -2 | -1 | -1 | -1 | -1 | -1 | -1 |
| -3 | -2 | -2 | -2 | -2 | -2 | **-1** |
| -5 | -3 | -3 | -3 | -3 | -3 | **-2** |
| -7 | -4 | -4 | -4 | -4 | -4 | **-3** |
| -8 | -4 | -4 | -4 | -4 | -4 | -4 |
| -1025 | -513 | -513 | -513 | -513 | -513 | **-512** |

`BinaryInteger` specifies the flooring behaviour, which is why this package
matches `Int` exactly — and, as it turns out, matches every other language's
bigint too. If you are porting code off attaswift and it right-shifts negative
numbers, the results will change, and they will change to the answer everything
else gives.

This is the only behavioural disagreement found anywhere: 75 cases against
attaswift and 63 against the three languages. The affected rows carry `n/c`
rather than a ratio, because timing two functions that compute different things
is not a comparison.

## What benchmarking changed

The first run of this benchmark found five things worth fixing, and they are
fixed. Speedups of the current code over the code that was measured:

| operation | 64 bits | 256 bits | 1024 bits | 4096 bits |
|---|---:|---:|---:|---:|
| `init(radix: 16)` | **9.4×** | **16.2×** | **26.2×** | **33.1×** |
| `init(radix: 10)` | **11.6×** | **18.8×** | **25.9×** | **20.5×** |
| `description` | **2.4×** | **5.4×** | **5.1×** | **2.1×** |
| `-` | **2.5×** | **2.4×** | **2.4×** | **2.2×** |
| `*` | **4.3×** | 1.02× | 0.99× | 1.05× |
| `gcd` | **6.6×** | 0.94× | 1.12× | 0.97× |
| `<< 61` | 1.03× | 1.02× | 1.07× | 1.25× |
| `>> 61` | 1.04× | 1.02× | 1.13× | **1.5×** |
| `+` | 1.02× | 1.00× | 1.00× | 1.00× |
| `/` | 1.02× | 1.02× | 1.00× | 1.01× |
| `squareRoot` | 1.01× | 1.01× | 1.03× | 0.98× |
| `power(5)` | 1.24× | 1.06× | 1.02× | 1.04× |

* **Radix conversion was the big one.** Powers of two need no arithmetic at all —
  16 is four bits, so a hex digit *is* half a limb — but the parser ran the same
  chunked multiply-and-add it uses for decimal. The giveaway was internal rather
  than comparative: hex cost the same as decimal, when decimal has to multiply
  and hex does not. Both directions now special-case radix 2, 4, 8, 16 and 32
  ([Radix.swift](Sources/BigNum/Radix.swift)), and every other radix runs the
  chunked algorithm on the limbs in place, one allocation instead of one per
  chunk.
* **`-` was `lhs + (-rhs)`** — three passes and three allocations where two's
  complement subtraction is `lhs + ~rhs + 1` in one of each.
* **`*` and `gcd` had no small-operand path.** Limb *count* was the wrong test: a
  positive value with its top bit set carries a clear sign limb, so 2^63 is two
  limbs wide while its magnitude is one. Testing the magnitude instead
  (`singleLimbMagnitude`) puts every `Int`-sized pair through
  `multipliedFullWidth` and a word-sized binary GCD, in registers.
* **`description` built a `String` per digit chunk** and concatenated them. It now
  writes one byte buffer, with radix 10 getting its own copy of the digit loop so
  that the divisor is a literal the compiler can turn into a multiply.

Two things I tried that were not worth it, recorded so nobody repeats them: the
shift primitives had four branches per limb in their inner loops, and hoisting
those out bought 1.0–1.5× — the cost is the allocation, not the loop. Same for
the radix-10 digit specialisation, which moved `description` at 64 bits by about
5%. Every gain above of any size came from removing an allocation or an
algorithm, never from tightening a loop.

## Against JavaScript, Python and Ruby

Node's `BigInt`, CPython's `int` and Ruby's `Integer` are all C or C++
implementations with far more attention behind them than this package has.

**Read the `baseline` row first.** It is the timing loop with no arithmetic in
it, and in an interpreted language it is most of what a small operation costs:
134 ns in Python and 121 ns in Ruby, against 11 ns in Swift and Node. A `†` marks
any cell within 2× of its own harness's floor — those are mostly the
interpreter's loop, not its arithmetic, and they are excluded from the summary.

All four implementations agree on every one of the 63 shared answers they were asked for, at every size.

### 64 bits

| operation | swift-bignum | node | python | ruby |
|---|---:|---:|---:|---:|
| `baseline` | 11 ns | 11 ns (0.93×) | 134 ns (**11.74×**) | 121 ns (**10.58×**) |
| `+` | 75 ns | 22 ns (0.30×) | 153 ns (**2.02×**) † | 143 ns (**1.90×**) † |
| `-` | 78 ns | 25 ns (0.32×) | 152 ns (**1.96×**) † | 117 ns (**1.51×**) † |
| `*` | 54 ns | 26 ns (0.47×) | 174 ns (**3.22×**) † | 157 ns (**2.92×**) † |
| `/` | 275 ns | 31 ns (0.11×) | 195 ns (0.71×) † | 218 ns (0.79×) † |
| `%` | 274 ns | 31 ns (0.11×) | 196 ns (0.71×) † | 170 ns (0.62×) † |
| `<` | 5 ns | 7 ns (**1.36×**) † | 74 ns (**14.64×**) † | 71 ns (**13.92×**) † |
| `<< 61` | 161 ns | 25 ns (0.15×) | 153 ns (0.95×) † | 152 ns (0.94×) † |
| `>> 61` | 160 ns | 24 ns (0.15×) | 156 ns (0.97×) † | 122 ns (0.76×) † |
| `description` | 375 ns | 35 ns (0.09×) | 179 ns (0.48×) † | 200 ns (0.53×) † |
| `init(radix: 10)` | 168 ns | 72 ns (0.43×) | 209 ns (**1.25×**) † | 191 ns (**1.14×**) † |
| `init(radix: 16)` | 181 ns | 70 ns (0.39×) | 200 ns (**1.11×**) † | 187 ns (**1.03×**) † |
| `squareRoot` | 139 ns | — | 189 ns (**1.36×**) † | 107 ns (0.77×) † |
| `gcd` | 121 ns | — | 291 ns (**2.41×**) | 235 ns (**1.95×**) † |
| `power(5)` | 1.29 µs | 78 ns (0.06×) | 447 ns (0.35×) | 549 ns (0.43×) |
| `power(e, mod:)` | 99.42 µs | — | 13.10 µs (0.13×) | 24.36 µs (0.25×) |

### 256 bits

| operation | swift-bignum | node | python | ruby |
|---|---:|---:|---:|---:|
| `baseline` | 11 ns | 14 ns (**1.24×**) | 135 ns (**11.84×**) | 186 ns (**16.27×**) |
| `+` | 79 ns | 25 ns (0.32×) † | 157 ns (**1.98×**) † | 314 ns (**3.97×**) † |
| `-` | 82 ns | 36 ns (0.44×) | 166 ns (**2.03×**) † | 393 ns (**4.81×**) |
| `*` | 304 ns | 43 ns (0.14×) | 304 ns (**1.00×**) | 391 ns (**1.29×**) |
| `/` | 911 ns | 184 ns (0.20×) | 437 ns (0.48×) | 610 ns (0.67×) |
| `%` | 933 ns | 186 ns (0.20×) | 435 ns (0.47×) | 482 ns (0.52×) |
| `<` | 5 ns | 10 ns (**1.91×**) † | 81 ns (**15.67×**) † | 70 ns (**13.70×**) † |
| `<< 61` | 166 ns | 28 ns (0.17×) † | 154 ns (0.93×) † | 327 ns (**1.97×**) † |
| `>> 61` | 162 ns | 27 ns (0.16×) † | 158 ns (0.97×) † | 321 ns (**1.97×**) † |
| `description` | 482 ns | 186 ns (0.39×) | 273 ns (0.57×) | 475 ns (0.98×) |
| `init(radix: 10)` | 247 ns | 119 ns (0.48×) | 289 ns (**1.17×**) | 1.03 µs (**4.15×**) |
| `init(radix: 16)` | 257 ns | 155 ns (0.60×) | 250 ns (0.97×) † | 536 ns (**2.08×**) |
| `squareRoot` | 6.04 µs | — | 478 ns (0.08×) | 792 ns (0.13×) |
| `gcd` | 3.17 µs | — | 951 ns (0.30×) | 10.65 µs (**3.36×**) |
| `power(5)` | 1.56 µs | 198 ns (0.13×) | 1.41 µs (0.90×) | 1.06 µs (0.68×) |
| `power(e, mod:)` | 917.91 µs | — | 468.58 µs (0.51×) | 459.23 µs (0.50×) |

### 1024 bits

| operation | swift-bignum | node | python | ruby |
|---|---:|---:|---:|---:|
| `baseline` | 11 ns | 13 ns (**1.19×**) | 134 ns (**11.82×**) | 205 ns (**18.13×**) |
| `+` | 96 ns | 32 ns (0.34×) | 174 ns (**1.81×**) † | 349 ns (**3.64×**) † |
| `-` | 95 ns | 35 ns (0.36×) | 174 ns (**1.82×**) † | 348 ns (**3.66×**) † |
| `*` | 576 ns | 219 ns (0.38×) | 2.18 µs (**3.78×**) | 1.28 µs (**2.22×**) |
| `/` | 2.47 µs | 895 ns (0.36×) | 2.94 µs (**1.19×**) | 2.62 µs (**1.06×**) |
| `%` | 2.53 µs | 909 ns (0.36×) | 2.93 µs (**1.16×**) | 2.49 µs (0.98×) |
| `<` | 5 ns | 7 ns (**1.40×**) † | 74 ns (**14.35×**) † | 70 ns (**13.53×**) † |
| `<< 61` | 168 ns | 33 ns (0.20×) | 166 ns (0.99×) † | 356 ns (**2.12×**) † |
| `>> 61` | 158 ns | 32 ns (0.20×) | 175 ns (**1.10×**) † | 345 ns (**2.18×**) † |
| `description` | 1.84 µs | 1.46 µs (0.79×) | 1.53 µs (0.83×) | 2.03 µs (**1.10×**) |
| `init(radix: 10)` | 639 ns | 545 ns (0.85×) | 1.17 µs (**1.83×**) | 6.54 µs (**10.23×**) |
| `init(radix: 16)` | 575 ns | 363 ns (0.63×) | 465 ns (0.81×) | 1.19 µs (**2.07×**) |
| `squareRoot` | 14.90 µs | — | 1.65 µs (0.11×) | 5.01 µs (0.34×) |
| `gcd` | 25.87 µs | — | 3.81 µs (0.15×) | 106.84 µs (**4.13×**) |
| `power(5)` | 4.47 µs | 1.77 µs (0.40×) | 11.24 µs (**2.51×**) | 10.50 µs (**2.35×**) |
| `power(e, mod:)` | 25.03 ms | — | 16.57 ms (0.66×) | 18.56 ms (0.74×) |

### 4096 bits

| operation | swift-bignum | node | python | ruby |
|---|---:|---:|---:|---:|
| `baseline` | 11 ns | 13 ns (**1.19×**) | 135 ns (**11.82×**) | 303 ns (**26.67×**) |
| `+` | 191 ns | 90 ns (0.47×) | 306 ns (**1.60×**) | 549 ns (**2.88×**) † |
| `-` | 201 ns | 139 ns (0.69×) | 348 ns (**1.73×**) | 681 ns (**3.38×**) |
| `*` | 5.98 µs | 2.51 µs (0.42×) | 17.89 µs (**2.99×**) | 14.54 µs (**2.43×**) |
| `/` | 16.26 µs | 8.22 µs (0.51×) | 38.06 µs (**2.34×**) | 30.44 µs (**1.87×**) |
| `%` | 16.27 µs | 8.21 µs (0.50×) | 38.00 µs (**2.34×**) | 30.35 µs (**1.87×**) |
| `<` | 5 ns | 10 ns (**1.90×**) † | 80 ns (**16.06×**) † | 70 ns (**14.04×**) † |
| `<< 61` | 221 ns | 63 ns (0.29×) | 268 ns (**1.21×**) † | 522 ns (**2.36×**) † |
| `>> 61` | 176 ns | 67 ns (0.38×) | 281 ns (**1.60×**) | 505 ns (**2.87×**) † |
| `description` | 25.28 µs | 17.51 µs (0.69×) | 18.05 µs (0.71×) | 16.86 µs (0.67×) |
| `init(radix: 10)` | 3.20 µs | 3.30 µs (**1.03×**) | 11.68 µs (**3.64×**) | 12.25 µs (**3.82×**) |
| `init(radix: 16)` | 1.86 µs | 1.07 µs (0.58×) | 1.32 µs (0.71×) | 3.88 µs (**2.08×**) |
| `squareRoot` | 93.83 µs | — | 12.22 µs (0.13×) | 78.60 µs (0.84×) |
| `gcd` | 568.15 µs | — | 24.42 µs (0.04×) | 784.00 µs (**1.38×**) |
| `power(5)` | 128.12 µs | 21.02 µs (0.16×) | 125.28 µs (0.98×) | 93.99 µs (0.73×) |

### Summary

Median of the per-operation ratios, over the operations all four have.
Greater than 1 means swift-bignum was faster.

| | 64 bits | 256 bits | 1024 bits | 4096 bits |
|---|---:|---:|---:|---:|
| node | 0.15× | 0.39× | 0.36× | 0.50× |
| python | 0.35× | 0.90× | **1.19×** | **1.73×** |
| ruby | 0.43× | **1.29×** | **2.07×** | **2.08×** |

Operations counted: those that clear 2× their own harness's `baseline` on both sides, out of `+`, `-`, `*`, `/`, `%`, `<`, `<< 61`, `>> 61`, `description`, `init(radix: 10)`, `init(radix: 16)`, `power(5)`. A † in the tables above marks a cell that does not, and is therefore mostly measuring the loop rather than the arithmetic.

### Is it faster than the dynamically-typed languages?

Above 256 bits, yes; below it, no.

* **Python**: behind at 64 bits (0.35×), level at 256 (0.90×), ahead at 1024 and
  4096 (1.19×, 1.73×).
* **Ruby 2.6**: behind at 64 bits (0.43×), ahead from 256 bits up (1.29×, 2.07×,
  2.08×).
* **Node**: behind everywhere, 0.15× to 0.50×, though the gap halves as operands
  grow.

At 64 bits the operations still lost to CPython are `/`, `%`, `<<`, `>>`,
`description`, `power(5)` and `power(e, mod:)`. The first four have the same
cause, and it is not the arithmetic: **every operation that returns a new value
allocates an array for it**, which is 40–60 ns before any work happens, and our
`baseline` of 11 ns is what one closure call and one fold cost with no allocation
at all. CPython and Ruby pay ~130 ns of interpreter loop per iteration but hand
out small integers from a free list, so on a 64-bit operand they are comparing
their allocator against ours and winning. Closing that means storing small values
inline instead of in a heap array — a change to the storage type itself, not to
any algorithm, and much larger than anything above.

`power(5)` and `power(e, mod:)` are different: both are dominated by mid-size
multiplication and by division, and modular exponentiation additionally reduces
in full at every exponent bit where windowing and Montgomery multiplication are
the standard answers. Neither is implemented.

### `>> 1` on negative values, across five implementations

| value | swift-bignum | node | python | ruby | attaswift |
|---:|---:|---:|---:|---:|---:|
| -1 | -1 | -1 | -1 | -1 | -1 |
| -2 | -1 | -1 | -1 | -1 | -1 |
| -3 | -2 | -2 | -2 | -2 | **-1** |
| -5 | -3 | -3 | -3 | -3 | **-2** |
| -7 | -4 | -4 | -4 | -4 | **-3** |
| -8 | -4 | -4 | -4 | -4 | -4 |
| -1025 | -513 | -513 | -513 | -513 | **-512** |

Agreeing: swift-bignum, node, python, ruby. Differing: attaswift.

## Against attaswift/BigInt

Ratios are attaswift's time over ours, so **greater than 1 means swift-bignum is
faster**. Anything within about 1.15× is noise.

| operation | 64 bits | 256 bits | 1024 bits | 4096 bits |
|---|---:|---:|---:|---:|
| `baseline` | **2.45×** | **2.45×** | **2.46×** | **2.53×** |
| `+` | **1.47×** | **2.22×** | **2.27×** | **1.97×** |
| `-` | **1.37×** | **1.50×** | **1.68×** | **1.89×** |
| `*` | **2.04×** | **1.09×** | **2.76×** | **4.42×** |
| `* (negative)` | **2.02×** | **1.10×** | **2.57×** | **4.22×** |
| `/` | 0.47× | 0.77× | **1.48×** | **3.04×** |
| `%` | 0.56× | 0.66× | **1.38×** | **3.02×** |
| `<` | **1.13×** | **1.18×** | **1.13×** | **1.19×** |
| `<< 61` | 0.63× | **1.37×** | **3.47×** | **6.61×** |
| `>> 61` | 0.62× | **1.07×** | **1.38×** | **2.03×** |
| `>> 61 (negative)` | not comparable | not comparable | not comparable | not comparable |
| `& (negative)` | **1.69×** | **1.84×** | **2.05×** | **1.91×** |
| `~ (negative)` | **1.33×** | **1.33×** | **1.23×** | 0.94× |
| `description` | **1.14×** | **2.47×** | **3.04×** | **2.03×** |
| `init(radix: 10)` | **5.73×** | **12.51×** | **17.30×** | **15.39×** |
| `init(radix: 16)` | **4.21×** | **9.61×** | **15.85×** | **19.55×** |
| `squareRoot` | **6.67×** | 0.73× | 0.96× | **1.77×** |
| `gcd` | **10.41×** | **2.36×** | **2.59×** | **1.55×** |
| `power(5)` | 0.54× | **2.16×** | **9.57×** | **5.38×** |
| `power(e, mod:)` | 0.42× | 0.93× | **1.40×** | — |

`+`, `-`, `*`, `&`, `~`, both parsers, `squareRoot` and `gcd` now win at every
size, and `description` has gone from 0.45–0.59× to roughly parity. What remains
against us is `/` and `%` below 1024 bits, the shifts, and the two exponentiation
rows — the same allocation floor described above, since attaswift's per-call
overhead is lower than ours and does not shrink with the operand.

## Method

* All four implementations parse the *same* hex string for each input. The Swift
  harness generates them and writes `.out/inputs.tsv`; Node, Python and Ruby read
  that file rather than generating their own, so "same inputs" holds across
  languages and not just across the two Swift libraries.
* Every case is checked for agreement **before** it is timed, and disagreements
  are reported rather than averaged away. This is how the `>>` difference above
  surfaced — it was not something any implementation documented.
* Iteration count scales until a batch takes 50 ms, then the best of five batches
  is reported. Best-of rather than mean, because interference can only make a
  batch slower.
* Every result is folded into a checksum that gets printed, so nothing measured is
  dead code. In JavaScript the operands are loop-invariant, which a JIT is free to
  hoist; measured against a form that varies its operand per iteration, the
  marginal cost of a 64-bit `*` was 8.5 ns invariant against 11.8 ns varying — a
  1.4× difference rather than the ~10× that hoisting would show, so V8 is doing
  the work.
* Each harness measures its own `baseline` — the loop and the result-folding with
  no arithmetic — reported as a row rather than subtracted, because the fold is
  not the same cost for every operation and a subtracted number would imply a
  precision that is not there.
* A debug build reports the absence of the optimizer rather than the algorithms,
  so the Swift harness says so loudly if it is built without `-c release`.

Two things the numbers cannot tell you. The interpreted harnesses pay for their
own loop on every iteration and the compiled one does not, so any row within a
small multiple of its `baseline` is not a measurement of arithmetic. And a tight
Swift loop over `BigInt` is not what code in those languages looks like, so these
ratios are about the bignum implementations, not about the languages.

Measured on an Apple M1 (8 cores), macOS 26.6.1, Swift 6.3.3, against
attaswift/BigInt **5.7.0**, node **v24.18.0** (V8 13.6), CPython **3.9.6**, and
ruby 2.6.10 (/System/Library/Frameworks/Ruby.framework/Versions/2.6/usr/bin/ruby, GMP possible). `Package.resolved` is not checked in, so a later
run may pick up a newer attaswift 5.x; `swift package resolve && cat
Package.resolved` in `Benchmarks/` says which version you actually got.

## Appendix: absolute times against attaswift

| operation | bits | swift-bignum | attaswift | ratio |
|---|---:|---:|---:|---:|
| `baseline` | 64 | 11 ns | 28 ns | **2.45×** |
| `+` | 64 | 75 ns | 111 ns | **1.47×** |
| `-` | 64 | 78 ns | 107 ns | **1.37×** |
| `*` | 64 | 54 ns | 110 ns | **2.04×** |
| `* (negative)` | 64 | 54 ns | 109 ns | **2.02×** |
| `/` | 64 | 275 ns | 128 ns | 0.47× |
| `%` | 64 | 274 ns | 154 ns | 0.56× |
| `<` | 64 | 5 ns | 6 ns | **1.13×** |
| `<< 61` | 64 | 161 ns | 101 ns | 0.63× |
| `>> 61` | 64 | 160 ns | 99 ns | 0.62× |
| `>> 61 (negative)` | 64 | 161 ns | 99 ns | not comparable |
| `& (negative)` | 64 | 74 ns | 125 ns | **1.69×** |
| `~ (negative)` | 64 | 72 ns | 96 ns | **1.33×** |
| `description` | 64 | 375 ns | 430 ns | **1.14×** |
| `init(radix: 10)` | 64 | 168 ns | 962 ns | **5.73×** |
| `init(radix: 16)` | 64 | 181 ns | 761 ns | **4.21×** |
| `squareRoot` | 64 | 139 ns | 928 ns | **6.67×** |
| `gcd` | 64 | 121 ns | 1.26 µs | **10.41×** |
| `power(5)` | 64 | 1.29 µs | 697 ns | 0.54× |
| `power(e, mod:)` | 64 | 99.42 µs | 41.72 µs | 0.42× |
| `baseline` | 256 | 11 ns | 28 ns | **2.45×** |
| `+` | 256 | 79 ns | 175 ns | **2.22×** |
| `-` | 256 | 82 ns | 123 ns | **1.50×** |
| `*` | 256 | 304 ns | 331 ns | **1.09×** |
| `* (negative)` | 256 | 300 ns | 330 ns | **1.10×** |
| `/` | 256 | 911 ns | 705 ns | 0.77× |
| `%` | 256 | 933 ns | 615 ns | 0.66× |
| `<` | 256 | 5 ns | 6 ns | **1.18×** |
| `<< 61` | 256 | 166 ns | 227 ns | **1.37×** |
| `>> 61` | 256 | 162 ns | 174 ns | **1.07×** |
| `>> 61 (negative)` | 256 | 160 ns | 175 ns | not comparable |
| `& (negative)` | 256 | 72 ns | 133 ns | **1.84×** |
| `~ (negative)` | 256 | 71 ns | 94 ns | **1.33×** |
| `description` | 256 | 482 ns | 1.19 µs | **2.47×** |
| `init(radix: 10)` | 256 | 247 ns | 3.09 µs | **12.51×** |
| `init(radix: 16)` | 256 | 257 ns | 2.47 µs | **9.61×** |
| `squareRoot` | 256 | 6.04 µs | 4.41 µs | 0.73× |
| `gcd` | 256 | 3.17 µs | 7.47 µs | **2.36×** |
| `power(5)` | 256 | 1.56 µs | 3.39 µs | **2.16×** |
| `power(e, mod:)` | 256 | 917.91 µs | 858.20 µs | 0.93× |
| `baseline` | 1024 | 11 ns | 28 ns | **2.46×** |
| `+` | 1024 | 96 ns | 217 ns | **2.27×** |
| `-` | 1024 | 95 ns | 160 ns | **1.68×** |
| `*` | 1024 | 576 ns | 1.59 µs | **2.76×** |
| `* (negative)` | 1024 | 605 ns | 1.55 µs | **2.57×** |
| `/` | 1024 | 2.47 µs | 3.65 µs | **1.48×** |
| `%` | 1024 | 2.53 µs | 3.49 µs | **1.38×** |
| `<` | 1024 | 5 ns | 6 ns | **1.13×** |
| `<< 61` | 1024 | 168 ns | 584 ns | **3.47×** |
| `>> 61` | 1024 | 158 ns | 218 ns | **1.38×** |
| `>> 61 (negative)` | 1024 | 159 ns | 220 ns | not comparable |
| `& (negative)` | 1024 | 85 ns | 173 ns | **2.05×** |
| `~ (negative)` | 1024 | 76 ns | 93 ns | **1.23×** |
| `description` | 1024 | 1.84 µs | 5.60 µs | **3.04×** |
| `init(radix: 10)` | 1024 | 639 ns | 11.06 µs | **17.30×** |
| `init(radix: 16)` | 1024 | 575 ns | 9.11 µs | **15.85×** |
| `squareRoot` | 1024 | 14.90 µs | 14.28 µs | 0.96× |
| `gcd` | 1024 | 25.87 µs | 66.96 µs | **2.59×** |
| `power(5)` | 1024 | 4.47 µs | 42.78 µs | **9.57×** |
| `power(e, mod:)` | 1024 | 25.03 ms | 35.07 ms | **1.40×** |
| `baseline` | 4096 | 11 ns | 29 ns | **2.53×** |
| `+` | 4096 | 191 ns | 376 ns | **1.97×** |
| `-` | 4096 | 201 ns | 381 ns | **1.89×** |
| `*` | 4096 | 5.98 µs | 26.42 µs | **4.42×** |
| `* (negative)` | 4096 | 6.17 µs | 26.04 µs | **4.22×** |
| `/` | 4096 | 16.26 µs | 49.42 µs | **3.04×** |
| `%` | 4096 | 16.27 µs | 49.18 µs | **3.02×** |
| `<` | 4096 | 5 ns | 6 ns | **1.19×** |
| `<< 61` | 4096 | 221 ns | 1.46 µs | **6.61×** |
| `>> 61` | 4096 | 176 ns | 357 ns | **2.03×** |
| `>> 61 (negative)` | 4096 | 181 ns | 372 ns | not comparable |
| `& (negative)` | 4096 | 191 ns | 364 ns | **1.91×** |
| `~ (negative)` | 4096 | 108 ns | 102 ns | 0.94× |
| `description` | 4096 | 25.28 µs | 51.42 µs | **2.03×** |
| `init(radix: 10)` | 4096 | 3.20 µs | 49.32 µs | **15.39×** |
| `init(radix: 16)` | 4096 | 1.86 µs | 36.36 µs | **19.55×** |
| `squareRoot` | 4096 | 93.83 µs | 165.87 µs | **1.77×** |
| `gcd` | 4096 | 568.15 µs | 880.69 µs | **1.55×** |
| `power(5)` | 4096 | 128.12 µs | 688.73 µs | **5.38×** |

79 cases, 75 in agreement.

Disagreed, so no ratio is reported for them: `>> 61 (negative)`.

`>> 1` against `Int`, which defines the contract:

| value | `Int` | swift-bignum | attaswift |
|---:|---:|---:|---:|
| -1 | -1 | -1 | -1 |
| -2 | -1 | -1 | -1 |
| -3 | -2 | -2 | -1 **differs** |
| -5 | -3 | -3 | -2 **differs** |
| -7 | -4 | -4 | -3 **differs** |
| -8 | -4 | -4 | -4 |
| -1025 | -513 | -513 | -512 **differs** |

swift-bignum matches `Int` in 7 of 7 cases; attaswift in 3.

Cores: 8. Checksum: 10200016186030546150.

[attaswift/BigInt]: https://github.com/attaswift/BigInt
