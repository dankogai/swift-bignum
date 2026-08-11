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

This was the only behavioural disagreement found anywhere: 75 cases against
attaswift and 63 against the three languages, and this operation is the whole of
it. The affected rows carry `n/c` rather than a ratio, because timing two
functions that compute different things is not a comparison.

## Against JavaScript, Python and Ruby

Node's `BigInt`, CPython's `int` and Ruby's `Integer` are all C or C++
implementations that have had far more attention than this package has, so the
question is not whether they win but where and by how much.

**Read the `baseline` row first.** It is the timing loop with no arithmetic in
it, and in an interpreted language it is most of what a small operation costs:
135 ns in Python and 153–249 ns in Ruby, against 11 ns in Swift and Node. A `†`
marks any cell within 2× of its own harness's floor — those numbers are mostly
the interpreter's loop, not its arithmetic, and they are excluded from the
summary. At 64 bits nearly every Python and Ruby row carries one.

All four implementations agree on every one of the 63 shared answers they were asked for, at every size.

### 64 bits

| operation | swift-bignum | node | python | ruby |
|---|---:|---:|---:|---:|
| `baseline` | 11 ns | 11 ns (0.93×) | 135 ns (**11.80×**) | 153 ns (**13.36×**) |
| `+` | 77 ns | 22 ns (0.29×) | 153 ns (**1.99×**) † | 198 ns (**2.57×**) † |
| `-` | 193 ns | 24 ns (0.13×) | 153 ns (0.79×) † | 154 ns (0.80×) † |
| `*` | 233 ns | 24 ns (0.10×) | 174 ns (0.75×) † | 212 ns (0.91×) † |
| `/` | 279 ns | 30 ns (0.11×) | 196 ns (0.70×) † | 260 ns (0.93×) † |
| `%` | 280 ns | 30 ns (0.11×) | 195 ns (0.70×) † | 183 ns (0.66×) † |
| `<` | 5 ns | 7 ns (**1.31×**) † | 74 ns (**14.56×**) † | 106 ns (**20.76×**) † |
| `<< 61` | 167 ns | 24 ns (0.14×) | 154 ns (0.92×) † | 205 ns (**1.23×**) † |
| `>> 61` | 166 ns | 24 ns (0.14×) | 155 ns (0.93×) † | 152 ns (0.92×) † |
| `description` | 899 ns | 34 ns (0.04×) | 180 ns (0.20×) † | 199 ns (0.22×) † |
| `init(radix: 10)` | 1.95 µs | 70 ns (0.04×) | 210 ns (0.11×) † | 235 ns (0.12×) † |
| `init(radix: 16)` | 1.71 µs | 70 ns (0.04×) | 201 ns (0.12×) † | 229 ns (0.13×) † |
| `squareRoot` | 140 ns | — | 188 ns (**1.35×**) † | 121 ns (0.87×) † |
| `gcd` | 798 ns | — | 293 ns (0.37×) | 290 ns (0.36×) † |
| `power(5)` | 1.61 µs | 78 ns (0.05×) | 444 ns (0.28×) | 330 ns (0.21×) |
| `power(e, mod:)` | 100.11 µs | — | 13.16 µs (0.13×) | 13.66 µs (0.14×) |

### 256 bits

| operation | swift-bignum | node | python | ruby |
|---|---:|---:|---:|---:|
| `baseline` | 12 ns | 14 ns (**1.24×**) | 134 ns (**11.66×**) | 158 ns (**13.69×**) |
| `+` | 79 ns | 25 ns (0.32×) † | 159 ns (**2.00×**) † | 207 ns (**2.61×**) † |
| `-` | 197 ns | 36 ns (0.18×) | 166 ns (0.84×) † | 244 ns (**1.24×**) † |
| `*` | 309 ns | 42 ns (0.13×) | 307 ns (0.99×) | 266 ns (0.86×) † |
| `/` | 929 ns | 189 ns (0.20×) | 443 ns (0.48×) | 385 ns (0.41×) |
| `%` | 902 ns | 191 ns (0.21×) | 442 ns (0.49×) | 353 ns (0.39×) |
| `<` | 5 ns | 10 ns (**1.99×**) † | 81 ns (**16.17×**) † | 104 ns (**20.71×**) † |
| `<< 61` | 169 ns | 28 ns (0.16×) † | 154 ns (0.91×) † | 209 ns (**1.23×**) † |
| `>> 61` | 165 ns | 27 ns (0.16×) † | 157 ns (0.95×) † | 205 ns (**1.24×**) † |
| `description` | 2.58 µs | 187 ns (0.07×) | 270 ns (0.10×) | 405 ns (0.16×) |
| `init(radix: 10)` | 4.65 µs | 119 ns (0.03×) | 289 ns (0.06×) | 905 ns (0.19×) |
| `init(radix: 16)` | 4.16 µs | 158 ns (0.04×) | 247 ns (0.06×) † | 393 ns (0.09×) |
| `squareRoot` | 6.08 µs | — | 477 ns (0.08×) | 710 ns (0.12×) |
| `gcd` | 2.97 µs | — | 942 ns (0.32×) | 6.09 µs (**2.05×**) |
| `power(5)` | 1.66 µs | 204 ns (0.12×) | 1.39 µs (0.84×) | 775 ns (0.47×) |
| `power(e, mod:)` | 920.19 µs | — | 466.28 µs (0.51×) | 342.30 µs (0.37×) |

### 1024 bits

| operation | swift-bignum | node | python | ruby |
|---|---:|---:|---:|---:|
| `baseline` | 11 ns | 14 ns (**1.28×**) | 133 ns (**11.86×**) | 174 ns (**15.45×**) |
| `+` | 96 ns | 33 ns (0.35×) | 173 ns (**1.81×**) † | 241 ns (**2.52×**) † |
| `-` | 227 ns | 35 ns (0.15×) | 171 ns (0.76×) † | 242 ns (**1.07×**) † |
| `*` | 573 ns | 219 ns (0.38×) | 2.20 µs (**3.83×**) | 1.06 µs (**1.85×**) |
| `/` | 2.47 µs | 905 ns (0.37×) | 2.90 µs (**1.17×**) | 2.41 µs (0.98×) |
| `%` | 2.45 µs | 905 ns (0.37×) | 2.92 µs (**1.19×**) | 2.32 µs (0.94×) |
| `<` | 5 ns | 7 ns (**1.48×**) † | 74 ns (**14.68×**) † | 106 ns (**20.96×**) † |
| `<< 61` | 181 ns | 33 ns (0.18×) | 165 ns (0.91×) † | 235 ns (**1.30×**) † |
| `>> 61` | 179 ns | 32 ns (0.18×) | 173 ns (0.97×) † | 228 ns (**1.28×**) † |
| `description` | 9.39 µs | 1.46 µs (0.16×) | 1.47 µs (0.16×) | 1.99 µs (0.21×) |
| `init(radix: 10)` | 16.54 µs | 551 ns (0.03×) | 1.14 µs (0.07×) | 6.45 µs (0.39×) |
| `init(radix: 16)` | 15.06 µs | 361 ns (0.02×) | 457 ns (0.03×) | 1.04 µs (0.07×) |
| `squareRoot` | 15.29 µs | — | 1.65 µs (0.11×) | 2.35 µs (0.15×) |
| `gcd` | 28.99 µs | — | 3.76 µs (0.13×) | 44.44 µs (**1.53×**) |
| `power(5)` | 4.57 µs | 1.78 µs (0.39×) | 11.15 µs (**2.44×**) | 9.21 µs (**2.02×**) |
| `power(e, mod:)` | 25.15 ms | — | 16.33 ms (0.65×) | 17.78 ms (0.71×) |

### 4096 bits

| operation | swift-bignum | node | python | ruby |
|---|---:|---:|---:|---:|
| `baseline` | 11 ns | 14 ns (**1.20×**) | 136 ns (**11.92×**) | 249 ns (**21.76×**) |
| `+` | 190 ns | 89 ns (0.47×) | 305 ns (**1.60×**) | 406 ns (**2.13×**) † |
| `-` | 439 ns | 140 ns (0.32×) | 347 ns (0.79×) | 455 ns (**1.04×**) † |
| `*` | 6.25 µs | 2.52 µs (0.40×) | 17.88 µs (**2.86×**) | 14.41 µs (**2.30×**) |
| `/` | 16.47 µs | 8.22 µs (0.50×) | 37.71 µs (**2.29×**) | 30.10 µs (**1.83×**) |
| `%` | 16.06 µs | 8.29 µs (0.52×) | 37.96 µs (**2.36×**) | 29.93 µs (**1.86×**) |
| `<` | 5 ns | 10 ns (**1.92×**) † | 83 ns (**16.08×**) † | 102 ns (**19.82×**) † |
| `<< 61` | 276 ns | 64 ns (0.23×) | 272 ns (0.98×) † | 365 ns (**1.32×**) † |
| `>> 61` | 262 ns | 68 ns (0.26×) | 280 ns (**1.07×**) | 330 ns (**1.26×**) † |
| `description` | 53.28 µs | 17.59 µs (0.33×) | 17.83 µs (0.33×) | 16.55 µs (0.31×) |
| `init(radix: 10)` | 65.78 µs | 3.28 µs (0.05×) | 11.49 µs (0.17×) | 11.28 µs (0.17×) |
| `init(radix: 16)` | 61.54 µs | 1.08 µs (0.02×) | 1.29 µs (0.02×) | 3.44 µs (0.06×) |
| `squareRoot` | 92.03 µs | — | 12.30 µs (0.13×) | 11.67 µs (0.13×) |
| `gcd` | 553.87 µs | — | 24.55 µs (0.04×) | 513.02 µs (0.93×) |
| `power(5)` | 132.94 µs | 21.14 µs (0.16×) | 124.83 µs (0.94×) | 89.07 µs (0.67×) |

### Summary

Median of the per-operation ratios, over the operations all four have.
Greater than 1 means swift-bignum was faster.

| | 64 bits | 256 bits | 1024 bits | 4096 bits |
|---|---:|---:|---:|---:|
| node | 0.11× | 0.13× | 0.18× | 0.32× |
| python | 0.28× | 0.49× | **1.17×** | **1.07×** |
| ruby | 0.21× | 0.39× | 0.94× | 0.67× |

Operations counted: those that clear 2× their own harness's `baseline` on both sides, out of `+`, `-`, `*`, `/`, `%`, `<`, `<< 61`, `>> 61`, `description`, `init(radix: 10)`, `init(radix: 16)`, `power(5)`. A † in the tables above marks a cell that does not, and is therefore mostly measuring the loop rather than the arithmetic.

### What this says

* **V8 wins nearly everything.** Node is 0.11×–0.52× at every size and every
  operation except `<` and the `baseline` row itself. Its BigInt is a tuned C++
  implementation with a fast path for small values, and the gap narrows as
  operands grow — 0.11× median at 64 bits to 0.32× at 4096 — which is the same
  asymptotic story as the attaswift comparison, told from further behind.
* **Python and Ruby lose small, and win where the operands are large.** Both sit
  at 0.2–0.5× below 1024 bits, where their interpreter loop dominates. Above that
  the picture splits: Python's median crosses 1 (1.17× at 1024, 1.07× at 4096),
  while Ruby's peaks at 0.94× and falls back to 0.67× — but both beat us
  decisively on the two operations that dominate real bignum work. At 4096 bits
  CPython is 2.86× our `*` and 2.29× our `/`; Ruby is 2.30× and 1.83×.
* **Two gaps widen as the operands grow**, which is the signature of a
  different algorithm rather than a slower constant. See below.

### Where the gap widens with size, and where it is just a constant

Whether a gap grows as the operands grow is the interesting question: a widening
gap means a different algorithm, a flat one means a slower version of the same
idea. Ratios of CPython's time to ours, below 1 meaning CPython is faster:

| operation | 64 bits | 256 bits | 1024 bits | 4096 bits | |
|---|---:|---:|---:|---:|---|
| `init(radix: 16)` | 0.118 | 0.059 | 0.030 | 0.021 | widens |
| `gcd` | 0.367 | 0.317 | 0.130 | 0.044 | widens |
| `squareRoot` | 1.345 | 0.079 | 0.108 | 0.134 | flat |
| `description` | 0.200 | 0.105 | 0.157 | 0.335 | flat |

**Two of these are ours to fix, and the evidence is internal rather than
comparative:**

* **`init(radix: 16)` does work it does not need to.** At 4096 bits it costs
  61.5 µs against 1.08 µs in Node and 1.29 µs in Python, and the gap widens by
  nearly 6× from 64 bits to 4096 — the signature of quadratic against linear. The
  telling comparison is with our own decimal parser: hex costs 61.5 µs and
  decimal 65.8 µs, essentially the same. Decimal *has* to multiply. Hex does not,
  since 16 is a power of two and its digits can be packed straight into limbs. We
  run the same chunked multiply-and-add for both.
* **`gcd` stops scaling.** 553.9 µs at 4096 bits against CPython's 24.6 µs, the
  ratio falling from 0.37 to 0.04 as operands grow. Stein's binary GCD is a good
  choice when small — it beats attaswift by 1.6–2.9× at every size — but each step
  removes about one bit while touching every limb, so it is quadratic in the limb
  count. The subquadratic methods work on the leading words and apply the result
  to the whole number; a gap that widens like this is what points to one. Ruby, at
  513 µs, sits beside us rather than beside CPython.

**`squareRoot` and `description` are flat**, which makes them constant factors
rather than wrong algorithms — roughly 8–12× on the square root above 256 bits and
3–10× on decimal output, steady across sizes. Worth less than the two above.

`power(e, mod:)` is the near miss: 25.2 ms against Python's 16.3 ms at 1024 bits,
so 0.65×. Ours is square-and-multiply with a full reduction per exponent bit,
which is the naive schedule; windowed exponentiation and Montgomery
multiplication are the standard improvements, and neither is implemented here.

None of this is addressed in this change. Measuring is one job; fixing is another,
with its own tests.

## Against attaswift/BigInt

### Where each one wins

Ratios are attaswift's time over ours, so **greater than 1 means swift-bignum is
faster**. Anything within about 1.15× is noise (run-to-run variation on the same
machine was under 5%).

| operation | 64 bits | 256 bits | 1024 bits | 4096 bits |
|---|---:|---:|---:|---:|
| `+` | **1.48×** | **2.15×** | **2.27×** | **1.98×** |
| `-` | 0.56× | 0.63× | 0.70× | 0.85× |
| `*` | 0.48× | 1.09× | **2.74×** | **4.01×** |
| `* (negative)` | 0.49× | 1.10× | **2.54×** | **3.87×** |
| `/` | 0.47× | 0.77× | **1.42×** | **3.07×** |
| `%` | 0.56× | 0.67× | **1.35×** | **3.04×** |
| `<` | **1.20×** | **1.20×** | **1.20×** | **1.20×** |
| `<< 61` | 0.60× | **1.36×** | **3.23×** | **5.38×** |
| `>> 61` | 0.60× | 1.04× | **1.22×** | **1.37×** |
| `>> 61 (negative)` | n/c | n/c | n/c | n/c |
| `& (negative)` | **1.70×** | **1.84×** | **2.05×** | **1.93×** |
| `~ (negative)` | **1.31×** | **1.32×** | **1.18×** | 0.93× |
| `description` | 0.48× | 0.45× | 0.59× | 0.97× |
| `init(radix: 10)` | 0.50× | 0.63× | 0.70× | 0.76× |
| `init(radix: 16)` | 0.44× | 0.59× | 0.62× | 0.58× |
| `squareRoot` | **6.67×** | 0.71× | 0.96× | **1.74×** |
| `gcd` | **1.60×** | **2.38×** | **2.85×** | **1.59×** |
| `power(5)` | 0.44× | **2.11×** | **9.06×** | **5.11×** |
| `power(e, mod:)` | 0.42× | 0.93× | **1.33×** | — |

The pattern is asymptotic against constant. **swift-bignum wins as operands grow
and loses at one or two limbs**, and the crossover is visible in `*` (0.48× at 64
bits, 4.01× at 4096) and in `/` and `%`. Karatsuba above 40 limbs is part of it;
the rest is that attaswift's per-call overhead is lower and ours does not shrink
with the operand. `<< 61` costs us 166 ns on one limb and 275 ns on 64 of them —
a 64× larger input for 1.7× the time — which is a fixed cost per call, not work.

Three groups stand out:

* **Two's complement pays where it should.** `+`, `&` and `~` on negative values
  read straight off the storage, with no sign to case-analyse: 1.5–2.3× on `+`
  and 1.7–2.1× on `&` at every size. That was the reason for the representation
  and it shows up as expected.
* **`power` and `gcd` are the largest wins.** `power(5)` is 9× at 1024 bits, and
  Stein's binary gcd on the limbs is 1.6–2.9× throughout.
* **String conversion is the standing loss.** Both parsers are 0.44–0.76× at
  every size, and `description` is 0.45–0.59× until it reaches parity at 4096
  bits. Chunking by the largest power of the radix that fits a limb was supposed
  to settle this and evidently does not; attaswift is simply better at it.

### Two things this measured that look fixable

Neither is a design consequence, so they are worth recording as leads rather than
as facts about two's complement:

* **`-` is `lhs + (-rhs)`.** That is two passes over the limbs and two
  allocations where one of each would do, and it shows: our `-` costs 2.3–2.5×
  our `+` at every size, while attaswift's `-` is never slower than its `+`. It
  is the only arithmetic operation we lose at *every* size — and we win `+`
  everywhere by 1.5–2.3×, so the subtraction is leaving that on the table.
* **Small operands carry a constant we do not need.** Most of the 64-bit losses
  are in the 100–170 ns range against attaswift's ~100 ns, on work that is a
  handful of instructions. Allocation per result is the obvious suspect.

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
  no arithmetic — and it is reported as a row rather than subtracted, because the
  fold is not the same cost for every operation and a subtracted number would
  imply a precision that is not there.
* A debug build reports the absence of the optimizer rather than the algorithms,
  so the Swift harness says so loudly if it is built without `-c release`.

Two things the numbers cannot tell you. The interpreted harnesses pay for their
own loop on every iteration and the compiled one does not, so any row within a
small multiple of its `baseline` is not a measurement of arithmetic. And Node,
CPython and Ruby have no equivalent of the others' *language* overhead — a
tight Swift loop over `BigInt` is not what code in those languages looks like, so
these ratios are about the bignum implementations, not about the languages.

Measured on an Apple M1 (8 cores), macOS 26.6.1, Swift 6.3.3, against
attaswift/BigInt **5.7.0**, node **v24.18.0** (V8 13.6), CPython **3.9.6**, and
Ruby **4.0.6** built `--without-gmp` — which matters, since a GMP-backed Ruby
would be a different measurement entirely at the large sizes.
`Package.resolved` is not checked in, so a later run may pick up a newer
attaswift 5.x; `swift package resolve && cat Package.resolved` in `Benchmarks/`
says which version you actually got.

## Appendix: absolute times against attaswift

| operation | bits | swift-bignum | attaswift | ratio |
| `+` | 64 | 75 ns | 111 ns | **1.48×** |
| `-` | 64 | 189 ns | 105 ns | 0.56× |
| `*` | 64 | 223 ns | 108 ns | 0.49× |
| `* (negative)` | 64 | 220 ns | 108 ns | 0.49× |
| `/` | 64 | 272 ns | 128 ns | 0.47× |
| `%` | 64 | 272 ns | 153 ns | 0.56× |
| `<` | 64 | 5 ns | 6 ns | **1.12×** |
| `<< 61` | 64 | 166 ns | 99 ns | 0.60× |
| `>> 61` | 64 | 165 ns | 99 ns | 0.60× |
| `>> 61 (negative)` | 64 | 166 ns | 99 ns | not comparable |
| `& (negative)` | 64 | 73 ns | 124 ns | **1.70×** |
| `~ (negative)` | 64 | 72 ns | 94 ns | **1.31×** |
| `description` | 64 | 892 ns | 424 ns | 0.48× |
| `init(radix: 10)` | 64 | 1.95 µs | 969 ns | 0.50× |
| `init(radix: 16)` | 64 | 1.72 µs | 762 ns | 0.44× |
| `squareRoot` | 64 | 137 ns | 914 ns | **6.65×** |
| `gcd` | 64 | 783 ns | 1.25 µs | **1.60×** |
| `power(5)` | 64 | 1.59 µs | 692 ns | 0.44× |
| `power(e, mod:)` | 64 | 99.91 µs | 41.58 µs | 0.42× |
| `+` | 256 | 79 ns | 170 ns | **2.16×** |
| `-` | 256 | 195 ns | 122 ns | 0.63× |
| `*` | 256 | 303 ns | 331 ns | **1.09×** |
| `* (negative)` | 256 | 302 ns | 331 ns | **1.09×** |
| `/` | 256 | 906 ns | 694 ns | 0.77× |
| `%` | 256 | 905 ns | 610 ns | 0.67× |
| `<` | 256 | 5 ns | 6 ns | **1.19×** |
| `<< 61` | 256 | 169 ns | 229 ns | **1.35×** |
| `>> 61` | 256 | 168 ns | 175 ns | **1.04×** |
| `>> 61 (negative)` | 256 | 168 ns | 175 ns | not comparable |
| `& (negative)` | 256 | 73 ns | 134 ns | **1.84×** |
| `~ (negative)` | 256 | 71 ns | 94 ns | **1.32×** |
| `description` | 256 | 2.60 µs | 1.18 µs | 0.46× |
| `init(radix: 10)` | 256 | 4.76 µs | 3.02 µs | 0.63× |
| `init(radix: 16)` | 256 | 4.20 µs | 2.49 µs | 0.59× |
| `squareRoot` | 256 | 6.05 µs | 4.28 µs | 0.71× |
| `gcd` | 256 | 3.09 µs | 7.35 µs | **2.38×** |
| `power(5)` | 256 | 1.61 µs | 3.40 µs | **2.12×** |
| `power(e, mod:)` | 256 | 933.72 µs | 868.71 µs | 0.93× |
| `+` | 1024 | 95 ns | 216 ns | **2.27×** |
| `-` | 1024 | 232 ns | 163 ns | 0.70× |
| `*` | 1024 | 583 ns | 1.60 µs | **2.74×** |
| `* (negative)` | 1024 | 630 ns | 1.60 µs | **2.54×** |
| `/` | 1024 | 2.50 µs | 3.55 µs | **1.42×** |
| `%` | 1024 | 2.52 µs | 3.41 µs | **1.36×** |
| `<` | 1024 | 5 ns | 6 ns | **1.12×** |
| `<< 61` | 1024 | 183 ns | 591 ns | **3.22×** |
| `>> 61` | 1024 | 181 ns | 221 ns | **1.23×** |
| `>> 61 (negative)` | 1024 | 182 ns | 221 ns | not comparable |
| `& (negative)` | 1024 | 85 ns | 174 ns | **2.06×** |
| `~ (negative)` | 1024 | 78 ns | 92 ns | **1.18×** |
| `description` | 1024 | 9.41 µs | 5.56 µs | 0.59× |
| `init(radix: 10)` | 1024 | 16.09 µs | 11.25 µs | 0.70× |
| `init(radix: 16)` | 1024 | 15.02 µs | 9.30 µs | 0.62× |
| `squareRoot` | 1024 | 15.12 µs | 14.46 µs | 0.96× |
| `gcd` | 1024 | 23.72 µs | 67.59 µs | **2.85×** |
| `power(5)` | 1024 | 4.61 µs | 41.76 µs | **9.07×** |
| `power(e, mod:)` | 1024 | 25.63 ms | 34.21 ms | **1.33×** |
| `+` | 4096 | 190 ns | 377 ns | **1.99×** |
| `-` | 4096 | 437 ns | 371 ns | 0.85× |
| `*` | 4096 | 6.17 µs | 24.76 µs | **4.02×** |
| `* (negative)` | 4096 | 6.38 µs | 24.70 µs | **3.87×** |
| `/` | 4096 | 16.06 µs | 49.27 µs | **3.07×** |
| `%` | 4096 | 15.96 µs | 48.53 µs | **3.04×** |
| `<` | 4096 | 5 ns | 6 ns | **1.19×** |
| `<< 61` | 4096 | 275 ns | 1.48 µs | **5.37×** |
| `>> 61` | 4096 | 264 ns | 362 ns | **1.37×** |
| `>> 61 (negative)` | 4096 | 264 ns | 363 ns | not comparable |
| `& (negative)` | 4096 | 189 ns | 365 ns | **1.93×** |
| `~ (negative)` | 4096 | 108 ns | 100 ns | 0.93× |
| `description` | 4096 | 52.84 µs | 51.46 µs | 0.97× |
| `init(radix: 10)` | 4096 | 65.92 µs | 50.06 µs | 0.76× |
| `init(radix: 16)` | 4096 | 61.88 µs | 36.13 µs | 0.58× |
| `squareRoot` | 4096 | 93.00 µs | 161.84 µs | **1.74×** |
| `gcd` | 4096 | 551.89 µs | 876.29 µs | **1.59×** |
| `power(5)` | 4096 | 134.93 µs | 689.73 µs | **5.11×** |

Ours and theirs are `BigInt` in both cases: signed, arbitrary precision. Both
libraries are being asked for the same answers, and — apart from the one row
above — both give them.

[attaswift/BigInt]: https://github.com/attaswift/BigInt
