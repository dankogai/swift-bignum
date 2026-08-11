# Benchmark

`BigInt` here against [attaswift/BigInt], the dependency this package used to
have. Same inputs, same machine, same run.

**This is not part of `swift test`.** The benchmark is a package of its own, so
running it is something you ask for:

```bash
cd Benchmarks && swift run -c release
```

It has to be its own package rather than a target in the root manifest, because
SwiftPM resolves every declared dependency whether or not the target using it is
being built — a benchmark target at the root would quietly end the "`swift build`
fetches nothing" property. Nothing in `Benchmarks/` is reachable from the root
package.

## The one thing to read if you read nothing else

**The two libraries disagree on `>>` for negative values, and attaswift is the
one that departs from the standard library.** `Int` shifts arithmetically — it
floors — and so does this package. attaswift shifts the magnitude and keeps the
sign, which truncates toward zero:

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

`BinaryInteger` specifies the flooring behaviour, which is why this package
matches `Int` exactly. If you are porting code off attaswift and it right-shifts
negative numbers, the results will change — and they will change to the answers
`Int` would have given. This is the only behavioural disagreement the benchmark
found across 75 cases; the `>> (negative)` rows below are therefore marked `n/c`,
since timing two functions that compute different things is not a comparison.

## Where each one wins

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

## Two things this measured that look fixable

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

* Both libraries parse the *same* hex string for each input, so neither is handed
  a representation the other has to convert first.
* Every case is checked for agreement **before** it is timed, and disagreements
  are reported rather than averaged away. This is how the `>>` difference above
  surfaced — it was not something either library documented.
* Iteration count scales until a batch takes 50 ms, then the best of five batches
  is reported. Best-of rather than mean, because interference can only make a
  batch slower.
* Every result is folded into a checksum that gets printed, so nothing measured
  is dead code.
* A debug build reports the absence of the optimizer rather than the algorithms,
  so the harness says so loudly if it is built without `-c release`.

Measured on an Apple M1 (8 cores), macOS 26.6.1, Swift 6.3.3, against
attaswift/BigInt **5.7.0**. `Package.resolved` is not checked in, so a later run
may pick up a newer 5.x — `swift package resolve && cat Package.resolved` in
`Benchmarks/` says which version you actually got.

Absolute times, as generated:

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
