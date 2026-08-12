[![Swift 6](https://img.shields.io/badge/swift-6-blue.svg)](https://swift.org)
[![Swift 5](https://img.shields.io/badge/swift-5-blue.svg)](https://swift.org)
[![MIT LiCENSE](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI via GitHub Actions](https://github.com/dankogai/swift-bignum/actions/workflows/swift.yml/badge.svg?branch=main)](https://github.com/dankogai/swift-bignum/actions/workflows/swift.yml)

# swift-bignum

Arbitrary-precision arithmetic for Swift, in Swift — **with no dependencies**.

```swift
import BigNum

BigInt(2).power(256)            // 115792089237316195423570985008687907853269984665640564039457584007913129639936
BigInt(3).power(BigInt(1) << 100, mod: 1000000007)  // 870513414 -- Python's pow(b, e, m)
BigInt(1000003).isPrime!        // true -- a Bool?, but never nil below 2^64
BigUInt.random(withExactWidth: 1024)   // a random 1024-bit value, unbiased
1000003.isPrime!                // ... and all of this works on Int and UInt8 too
1.over(3) + 1.over(6)           // (1/2) -- `over` turns two integers into a fraction
BigRat(1,3) + BigRat(1,3) + BigRat(1,3) == 1    // true.  Not "true to 17 digits".
BigFloat.sqrt(2)                // 1.414213562373095048801688724209698078569
BigRat.exp(1, precision:256)    // e to 256 bits
```

**This package depends on no other SwiftPM package — only on itself.** `swift build`
fetches nothing: the whole of it is this repository plus the Swift standard library
and the platform's libm. Up to 5.x there were two dependencies; both moved in, and
[Prerequisite](#prerequisite) says what and why.

## The four types

| Type | Is | Use it when |
|---|---|---|
| [`BigInt`](BigInt.md) | Arbitrary-precision signed integer, two's complement | Integers that must not overflow |
| [`BigUInt`](BigInt.md#biguint) | Its unsigned counterpart | Magnitudes, bit patterns wider than 64 |
| [`BigRat`](BigRat.md) | Exact rational, `BigInt` over `BigInt` | You need `1/3 + 1/3 + 1/3` to be exactly 1 |
| [`BigFloat`](BigFloat.md) | Binary floating point with an arbitrary mantissa | You need many digits, but bounded storage |

`BigInt` and `BigUInt` are ordinary `SignedInteger` and `UnsignedInteger`
conformances, so they behave the way `Int` and `UInt` do — including `&`, `|`,
`^`, `~` and an arithmetic `>>`. `BigRat` and `BigFloat` are `FloatingPoint`, and
both conform to `Real`, so the whole of `<math.h>` is available on them as static
functions.

`BigRat` and `BigFloat` divide the same job differently. A `BigRat` is *exact*:
it is a fraction, and it stays one, so its numerator and denominator grow without
bound as you compute. A `BigFloat` keeps a fixed number of significant bits, so
its storage stays put and its arithmetic rounds. The one-line version:

```swift
BigRat(1)/BigRat(3) * 3 == 1        // true  -- exact
BigFloat(1)/BigFloat(3) * 3 == 1    // false -- rounded to `precision` bits
```

## The built-in integers get all of it

`power`, `power(_:mod:)`, `isPrime`, `squareRoot`, `greatestCommonDivisor`,
`nextPrime`, `random` and the rest are on `Int`, `UInt`, `Int8` … `UInt64` and
`Int128` as well as on `BigInt`:

```swift
Int(2).power(10)                        // 1024
1000003.isPrime!                        // true
UInt8(200).nextPrime                    // 211
Int(2).power(1024, mod: 1_000_000_007)  // 812734592 -- no overflow, ever
Int.random(from: -100, to: 100)         // and .random, closed at both ends
Int.random()                            // ... or the whole range, min through max
```

Each widens to `BigInt`, computes there, and comes back — so where the answer
does not fit, it traps, exactly as `*` would. `Int(2).power(1024)` is not a number
an `Int` has, and `BigInt(2).power(1024)` is right there when you need it. The
modular form never overflows, which is what makes it worth having.
[BigInt.md](BigInt.md#on-the-built-in-integers-too) has the full table of which
operations can trap.

## `BigRat` and `BigFloat` as somebody else's real part

Being standalone cuts both ways, and the second way is the useful one. `BigRat` and
`BigFloat` are ordinary `FloatingPoint` conformances carrying the whole of
`<math.h>`, so they can serve as the **real part of any package that is generic over
one** — and nothing has to be agreed in advance, because the dependency runs
outward. swift-bignum knows nothing about the packages that use it, and does not
need to.

Two worked examples ship in this repository, each its own package so that this
manifest keeps fetching nothing:

| Example | Complex from | The conformance |
|---|---|---|
| [SwiftNumericsExample](SwiftNumericsExample/) | [apple/swift-numerics] | `extension BigRat: RealModule.Real {}` |
| [SwiftComplexExample](SwiftComplexExample/) | [dankogai/swift-complex] | `extension BigRat: RMath {}` |

Both give you `Complex<BigRat>` and `Complex<BigFloat>` for two empty extensions,
and both are only examples. Any package generic over a real type can take these:
a complex type is simply the case that shows it off, since it needs the whole of
`ElementaryFunctions` rather than just arithmetic.

```swift
Complex<BigRat>(1, 2) / Complex<BigRat>(3, 4)    // exactly (11+2i)/25 -- no rounding
Complex<BigFloat>.exp(Complex<BigFloat>(0, .pi)) // -1, to within 1e-39 at 128 bits
```

What it costs is not always nothing, and the two examples differ in exactly the way
worth knowing about: **a protocol whose functions are requirements composes; one
whose functions are extension defaults collides.** swift-numerics defaults four of
them — `sqrt`, `exp10`, `reciprocal`, `signGamma`, and `/` besides, for `BigRat` —
so those had to be settled on the concrete types here; see the end of
[Real.swift](Sources/BigNum/Real.swift). swift-complex declares its functions as
requirements, so nothing collides at all. Each example's README works through its
own case.

## The exponentiation operator, on demand

`**` is not part of `BigNum`. It lives in a second module, so it appears only
where you ask for it:

```swift
import BigNum                 // no ** in scope
import BigNumOperators        // ** available, and BigNum comes with it
```

```swift
2 ** 10                       // 1024              -- Int.power(10)
BigInt(2) ** 256              // exact              -- BigInt.power(256)
2.0 ** 0.5                    // 1.4142135623730951 -- Double.pow(2, 0.5)
BigFloat(2) ** 10             // 1024               -- BigFloat.pow(x, 10)
```

It forwards to `power` on the integers and to `pow` on the `Real`s, and carries
whatever those carry: `Int(2) ** 1024` traps like `*`, and `**` on a `BigRat`
rounds to `precision` bits — it is `pow`, not repeated multiplication, so
`BigRat(1,3) ** 2` is not `(1/9)` while `BigRat(1,3) * BigRat(1,3)` is.

Two notes on parsing. `**` binds tighter than `*` and associates to the right, so
`2 ** 3 ** 2` is 512. But Swift binds prefix `-` tighter than any infix operator,
so `-2 ** 2` is 4 where Python says -4; write `-(2 ** 2)` when you mean that.

Swift has no submodules, so `import BigNum.operators` is not a spelling that can
be built — a separate module is what the language offers, and it gates the
operator exactly the way you would want.

## `over`: fractions from integers

`over(_:)` is the idiomatic way to build a rational. It reads as the fraction bar —
`a.over(b)` is *a over b* — and it is defined on the integers, so you rarely need
to name a rational type at all:

```swift
1.over(3)                 // (1/3)  -- an IntRat, because 1 is an Int
BigInt(1).over(3)         // (1/3)  -- a BigRat, because the numerator is a BigInt
Int8(1).over(2)           // (1/2)  -- a FixedWidthRational<Int8>
6.over(4)                 // (3/2)  -- reduced on construction
6.over(-4)                // (-3/2) -- the sign moves to the numerator
```

**The numerator's type picks the rational's type.** An `Int` gives you an `IntRat`,
a `BigInt` gives you a `BigRat`, and any other `FixedWidthRationalElement` gives
you the `FixedWidthRational` over it. So `over` is how you choose between bounded
and unbounded arithmetic — by choosing what you call it on:

```swift
1.over(3) + 1.over(6)                    // (1/2), in two Ints
BigInt(1).over(3) + BigInt(1).over(6)    // (1/2), in two BigInts that can grow
```

Because they are ordinary fractions, the special values come out of the arithmetic
rather than from anywhere special:

```swift
BigInt(1).over(0)         // (1/0)  -- infinity
BigInt(0).over(0)         // (0/0)  -- NaN
BigInt(3260954456333195553).over(2305843009213693952).toDouble()   // 1.4142135623730951
BigRat.sqrt(2).toDouble()                                          // the same Double
```

On a rational rather than an integer, `over` divides — the same reading of the
fraction bar, one level up:

```swift
BigRat(1,2).over(BigRat(1,3))   // (3/2), the same as `/`
BigRat(1,2).over(BigInt(3))     // (1/6), dividing by a bare numerator type
```

## Precision

Every lossy operation takes an optional `precision:` in **bits**. Omit it and the
type's `precision` static is used, which starts at 128:

```swift
BigFloat.sqrt(2)                 // 1.414213562373095048801688724209698078569
BigFloat.sqrt(2, precision:32)   // 1.41421356215141713619
BigFloat.sqrt(2, precision:256)  // 1.414213562373095048801688724209698078569671875376948073176679737990732478462102

BigFloat.precision = 256         // or move the default
BigFloat.sqrt(2)                 // now 256 bits
```

Note the 32-bit answer above: it is the *exact* decimal expansion of a value that
is only accurate to 32 bits, so it stops agreeing with √2 after about ten digits.
Precision bounds the error, not the number of digits printed.

Unlike `Double`, neither type overflows where the answer exists:

```swift
Double.exp(1000)    // inf
BigFloat.exp(1000)  // 197007111401704699388887 ... and 411 more digits
```

## Strings

`toString(_:radix:)` renders three ways, and `description` and `debugDescription`
are built from it:

```swift
let q = BigRat.sqrt(2)
q.toString()                     // +1.414213562373095048801688724209698078569
q.toString(.fraction)            // (+240615969168004511545033772477625056927/170141183460469231731687303715884105728)
q.toString(.exponent)            // +0x1.6a09e667f3bcc908b2fb1366ea957d3ep0
q.toString(.fraction, radix:16)  // the same ratio in hex -- what a BigRat debugs as
```

`.point` takes any radix; `.fraction` announces a non-decimal one with
`0x`/`0o`/`0b`; `.exponent` is hexadecimal by definition — its `p` counts bits,
the way C's `%a` prints a `double`. `BigInt` and `BigUInt` have their own
`toString(radix:uppercase:)`, and both parse back with `init?(_:radix:)`.

## Usage

### Swift Package Manager

Add to the `dependencies` section:

```swift
.package(url: "https://github.com/dankogai/swift-bignum.git", .branch("main"))
```

and to your target:

```swift
.target(name: "YourPackage", dependencies: ["BigNum"])
```

Then `import BigNum`. That is the only import you need — `BigInt` comes with it.

### Build and test

```bash
git clone https://github.com/dankogai/swift-bignum.git && cd swift-bignum && swift test
```

### Benchmark

[Benchmark.md](Benchmark.md) measures `BigInt` against [attaswift/BigInt] and
against the bigints built into JavaScript, Python and Ruby. Both run only when
asked:

```bash
cd Benchmarks && swift run -c release      # against attaswift
cd Benchmarks && sh cross/run.sh           # and against node, python, ruby
```

Briefly: ahead of attaswift on most operations at every size; ahead of CPython
above 256 bits and of macOS's Ruby from 256 bits up; behind V8's `BigInt` everywhere,
and behind all three on 64-bit operands, where one heap allocation per result is
the floor. Five implementations were asked to right-shift a negative number and
attaswift is the only one that answers differently.

The first run of that benchmark is also why radix conversion is 9–33× faster than
it was, `-` 2.4×, and small `*` and `gcd` 4–7× — [Benchmark.md](Benchmark.md#what-benchmarking-changed)
records what it found and what each fix bought.

That is a separate package on purpose. A benchmark target in this manifest would
pull attaswift back in as a dependency of the root, and `swift build` would stop
fetching nothing.

### Playground

`macOS.playground` has a page per type — Synopsis, BigInt, BigRat, BigFloat,
Precision, and a Scratch page to work in. Open `Package.swift` in Xcode first so
the `BigNum` module is built, then open the playground.

## Documentation

* [BigInt.md](BigInt.md) — `BigInt` and `BigUInt`: representation, bit twiddling,
  division semantics, number theory, primality
* [BigRat.md](BigRat.md) — `BigRat`: exact rationals, the `FloatingPoint`
  conformance, `IntRat` and the other fixed-width rationals
* [BigFloat.md](BigFloat.md) — `BigFloat`: mantissa and scale, rounding,
  truncation, parsing
* [Benchmark.md](Benchmark.md) — `BigInt` against attaswift/BigInt, JavaScript,
  Python and Ruby, and the one place any of them disagree
* [CAVEAT.md](CAVEAT.md) — every way this `BigInt` is *not* a drop-in replacement
  for attaswift's, measured by compiling all 106 of its public members against
  ours
* [SwiftNumericsExample](SwiftNumericsExample/) and
  [SwiftComplexExample](SwiftComplexExample/) — `BigRat` and `BigFloat` as the real
  part of somebody else's `Complex`, one package each

# Prerequisite

Swift 6 or 5, macOS or Linux.

**No dependencies.** Up to version 5.x there were two:

* `BigInt` and `BigUInt` came from [attaswift/BigInt], which had to be re-exported
  with `@_exported import` for `import BigNum` alone to be enough — an
  undocumented corner of the language to be resting a public API on. They are now
  part of this package, and `BigInt` is stored in two's complement rather than
  sign-and-magnitude, which is what makes `words`, the bitwise operators and `>>`
  fall out correctly instead of needing to be re-derived.
* `Real` and the three protocols it inherits came from [apple/swift-numerics],
  which this package wanted for `ElementaryFunctions` alone. Apple's own `BigInt`
  never arrived there to justify carrying the rest. They are now declared in
  [Real.swift](Sources/BigNum/Real.swift) and
  [ElementaryFunctions.swift](Sources/BigNum/ElementaryFunctions.swift).
* Versions before that depended on [dankogai/swift-floatingpoint] for the
  `FloatingPointMath` protocols, replaced by `ElementaryFunctions`.

Code written against swift-numerics keeps compiling — the protocol requirement
sets are unchanged. Code written against attaswift's `BigInt` mostly does, but not
entirely: of its 106 public members, 50 compile against ours and 56 do not.
**[CAVEAT.md](CAVEAT.md) lists all of them**, along with the two differences that
compile and then behave differently. The largest groups are attaswift's random
generators, its `Data` serialization, and the API through which it publishes its
sign-and-magnitude word representation.

Two of those differences are worth repeating here:

* **`Codable`** — a `BigInt` now encodes as a base-16 string rather than
  attaswift's sign-and-words form, so archives written by 5.x will not decode.
* **`as*` conversions are now `to*()` methods** — `asDouble` became `toDouble()`,
  matching the `toString()` that was already there. Likewise `asBigRat`,
  `asMixed`, `asIntRat`, `asBigFloat`.

And one difference that is not a break so much as a correction: **`>>` on a
negative value floors**, as `Int` and `BinaryInteger` specify, where attaswift
shifts the magnitude and keeps the sign. `BigInt(-5) >> 1` is -3 here and -2
there. [Benchmark.md](Benchmark.md) has the comparison against `Int`.

[attaswift/BigInt]: https://github.com/attaswift/BigInt
[apple/swift-numerics]: https://github.com/apple/swift-numerics
[dankogai/swift-complex]: https://github.com/dankogai/swift-complex
[dankogai/swift-floatingpoint]: https://github.com/danogai/swift-floatingpoint

# License

[MIT](LICENSE)
