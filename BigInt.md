# BigInt and BigUInt

Arbitrary-precision integers. `BigInt` is a `SignedInteger`, `BigUInt` an
`UnsignedInteger`, and both are ordinary `BinaryInteger`s — everything you can do
to an `Int` you can do to a `BigInt`, minus the overflow.

```swift
import BigNum

BigInt(Int.max) * BigInt(Int.max)   // 85070591730234615847396907784232501249
BigInt(Int.max) + 1                 // 9223372036854775808
BigInt(2).power(256)                // 115792089237316195423570985008687907853269984665640564039457584007913129639936
```

## Representation

`BigInt` stores **two's complement** limbs — a little-endian `[UInt]` whose most
significant bit is taken to repeat forever to the left. Zero is the empty array
and -1 is a single all-ones limb.

The usual alternative is sign-and-magnitude: a `Bool` beside a `BigUInt`. That
makes multiplication and division trivial and everything else a special case.
`BinaryInteger` defines `words`, `&`, `|`, `^`, `~` and `>>` *in terms of* two's
complement, so a sign-and-magnitude type has to re-derive all six, negative zero
becomes representable and has to be legislated away, and `words` has to be
synthesized limb by limb. Storing two's complement directly means those all read
straight off the storage; only `*`, `/` and `squareRoot()` pay, by going through
`magnitude`, and their cost is dominated by the limb loop anyway.

You can see the representation through `words`:

```swift
BigInt(1).words              // [1]
BigInt(-1).words             // [18446744073709551615]
BigInt(1 << 63).words        // [9223372036854775808, 0]  -- a clear sign limb on top
```

That last one is the invariant: a positive value never leaves its top bit set, so
the sign is always readable from the last limb.

## Construction

```swift
BigInt(42)                                  // from any BinaryInteger
BigInt(-42)
BigInt(1) << 100                            // 1267650600228229401496703205376
let n: BigInt = 123456789                   // integer literals

BigInt("123456789012345678901234567890")!   // failable, radix 10 by default
BigInt("deadbeef", radix:16)!               // 3735928559
BigInt("-1010", radix:2)!                   // -10
BigInt("nonsense")                          // nil

BigInt(Double.pi)                           // 3     -- truncates toward zero
BigInt(exactly: 2.5)                        // nil   -- not an integer
BigInt(0x1p200)                             // 1606938044258990275541962092341162602522202993782792835301376
```

`init?(_:radix:)` accepts radices 2 through 36, an optional leading `+` or `-`,
and nothing else — no underscores, no whitespace. `BigUInt` refuses a `-`.

## Arithmetic

`+ - * / %` and their compound forms, with no overflow anywhere. Division
truncates toward zero and the remainder takes the sign of the dividend, exactly
as `Int` specifies:

```swift
BigInt(7)  / BigInt(2)    //  3
BigInt(-7) / BigInt(2)    // -3        -- toward zero, not floored
BigInt(-7) % BigInt(2)    // -1        -- the dividend's sign
BigInt(7)  % BigInt(-2)   //  1
BigInt(-7).quotientAndRemainder(dividingBy: 2)   // (quotient: -3, remainder: -1)
```

Division by zero traps, as it does for `Int`. `BigInt` has no `Int.min`, so
`BigInt.min / -1` — the one division that overflows for a fixed-width type — is
simply not a case here.

Internally, division is Knuth's Algorithm D and multiplication is schoolbook up to
40 limbs and Karatsuba above that.

## Bitwise operations and shifts

All two's complement, all with the signs you would expect from `Int`:

```swift
~BigInt(5)                //  -6      -- ~x == -x - 1
BigInt(-6) & BigInt(3)    //   2
BigInt(-6) | BigInt(3)    //  -5
BigInt(-6) ^ BigInt(3)    //  -7
```

`>>` is *arithmetic*, so it floors rather than truncating, and shifting a negative
value far enough right leaves -1 rather than 0:

```swift
BigInt(-5) >> 1           //  -3       -- floor(-2.5), like Int
BigInt(-1) >> 100         //  -1       -- not 0
BigInt(1)  >> 100         //   0
BigInt(1)  << -3          //   0       -- a negative count shifts the other way
```

Worth knowing if you are porting off attaswift/BigInt, which shifts the magnitude
and keeps the sign instead, so its `BigInt(-5) >> 1` is -2. `Int` floors, this
floors; see [Benchmark.md](Benchmark.md).

`~` on `BigUInt` is the one operator that cannot mean what it usually does: an
unsigned value has no width to complement within, so it flips the bits the value
currently occupies.

```swift
~BigUInt(0xff)            // 18446744073709551360  -- complement within one limb
~BigInt(0xff)             // -256                  -- the real thing
```

## Widths

`bitWidth` is the number of significant bits in the *magnitude*, plus one for the
sign. Zero is 0 bits wide.

| value | `bitWidth` |
|---|---|
| `BigInt(0)` | 0 |
| `BigInt(1)`, `BigInt(-1)` | 2 |
| `BigInt(2)`, `BigInt(-2)` | 3 |
| `BigInt(255)` | 9 |
| `BigInt(256)` | 10 |
| `BigUInt(0)` | 0 |
| `BigUInt(255)` | 8 |

This is not the tighter two's complement width in which -2 fits in two bits; it is
"the position of the top set bit, plus a sign bit", which is what the rest of this
package reads it as, and it matches what attaswift's `BigInt` returned. `BigUInt`
has no sign bit, so its `bitWidth` is just the significant bits.

`trailingZeroBitCount` reports 0 for zero rather than diverging, and ignores the
sign — negation does not move a value's trailing zeros:

```swift
BigInt(0).trailingZeroBitCount     // 0
BigInt(48).trailingZeroBitCount    // 4
BigInt(-48).trailingZeroBitCount   // 4
```

Also: `isZero`, `isNegative`, `magnitude` (a `BigUInt`), `signum()`.

```swift
BigInt(-5).magnitude               // 5, as a BigUInt
BigInt(-5).signum()                // -1
```

## Number theory

```swift
BigInt(2).power(64)                              // 18446744073709551616
BigInt(-2).power(3)                              // -8
BigInt(3).power(0)                               // 1
BigInt(5).power(-2)                              // 0   -- no integral reciprocal

BigInt(2).power(64).squareRoot()                 // 4294967296
BigInt(10).squareRoot()                          // 3   -- floor(sqrt(10))
(BigUInt(1) << 128).squareRoot()                 // 18446744073709551616

BigInt(1071).greatestCommonDivisor(with: 462)    // 21
BigInt(-12).greatestCommonDivisor(with: 18)      // 6   -- always non-negative
```

There is a `**` operator for `power(_:)`, in a separate module so that it stays
off unless imported — see [the README](README.md#the-exponentiation-operator-on-demand).

`squareRoot()` is ⌊√self⌋ by Newton's method and traps on a negative value.
`greatestCommonDivisor(with:)` is Stein's binary GCD, working on the limbs
directly — it is on `BigRat`'s hot path, since every rational reduces on
construction.

## `power(_:mod:)`: modular exponentiation

`power(_:mod:)` is Python's three-argument `pow()`. It is not `power(_:) % m`
— the intermediates are reduced as they are formed, which is what makes it
usable at all:

```swift
BigInt(2).power(10, mod: 1000)                    // 24
BigInt(123456789).power(12345, mod: 1000000007)   // 614455772
BigUInt(2).power(64, mod: (BigUInt(1) << 64) + 13)   // 18446744073709551616
```

Nothing ever grows past twice the modulus's width, so the cost is one squaring
per exponent bit rather than a result with `exponent * self.bitWidth` bits of it.
`BigInt(2).power(1000000, mod: 7)` is instant; `BigInt(2).power(1000000) % 7`
builds a million-bit number first.

Three conventions, all Python's:

**The result takes the sign of the modulus.** That is a floored remainder, unlike
the truncated one `%` gives:

```swift
BigInt(-2).power(3, mod: 5)     //  2      -- floored, in 0..<5
BigInt(-2).power(3) % 5         // -3      -- what `%` would say
BigInt(2).power(3, mod: -5)     // -2      -- a negative modulus, negative result
```

**A negative exponent raises the modular inverse**, by the extended Euclidean
algorithm — so `power(-1, mod:)` *is* the inverse:

```swift
BigInt(2).power(-1, mod: 5)     // 3   -- because 2*3 == 6 ≡ 1 (mod 5)
BigInt(3).power(-3, mod: 7)     // 6
BigInt(-3).power(-1, mod: 7)    // 2   -- -3 ≡ 4, and 4*2 ≡ 1
BigInt(2).power(-1, mod: 4)     // traps: 2 and 4 are not coprime
```

**A zero modulus traps**, and a modulus of 1 leaves nothing behind — not even for
an exponent of zero:

```swift
BigInt(5).power(3, mod: 1)      // 0
BigInt(2).power(0, mod: 5)      // 1
BigInt(2).power(0, mod: 1)      // 0
```

### Exponents wider than an `Int`

The exponent may also be a `Self`, which is the form cryptography needs — an RSA
exponent is as wide as its modulus:

```swift
let p = BigInt(1) << 127 - 1                  // a Mersenne prime
BigInt(3).power(p - 1, mod: p)                // 1, by Fermat's little theorem
BigUInt(3).power(BigUInt(1) << 100, mod: 1000000007)   // 870513414
```

A 2048-bit modexp with a 2048-bit exponent runs in tens of milliseconds in a
release build. There is deliberately no `power(_: Self)` without a modulus to match: an exponent
past `Int` has no representable answer there, since the result would want more
bits than the machine has.

## Conversions

```swift
Double(BigInt(1) << 100)     // 1.2676506002282294e+30   -- round to nearest even
Double(BigInt(1) << 2000)    // inf                      -- overflows like a Double
Int(BigInt(-7))              // -7                       -- traps if out of range
BigInt(-5).magnitude         // BigUInt(5)
BigUInt(truncatingIfNeeded: Int(-1))   // 18446744073709551615 -- the word pattern
BigUInt(clamping: Int(-1))             // 0
```

`Double(_:)` rounds to nearest, ties to even, and gives ±infinity when the value
is out of range — the same answer a `Double` arithmetic operation would give.

## Strings and Codable

```swift
BigInt(255).toString(radix:16)                    // "ff"
BigInt(255).toString(radix:16, uppercase:true)     // "FF"
BigInt(255).toString(radix:2)                      // "11111111"
String(BigInt(255), radix:8)                       // "377"
BigInt(255).description                            // "255"
```

`toString` divides by the largest power of the radix that fits in a limb —
10^19 for decimal — so it produces nineteen digits per bignum division instead of
one, which is what the generic `BinaryInteger` formatter would do.

`Codable` uses a single base-16 string:

```swift
try JSONEncoder().encode(BigInt(255))       // "ff"
try JSONEncoder().encode(BigInt(-255))      // "-ff"
try JSONEncoder().encode(BigInt(1) << 100)  // "10000000000000000000000000"
```

Words-plus-sign would encode faster, but a string stays readable in a JSON dump
and cannot be invalidated by a change of limb width. **This is not compatible with
attaswift/BigInt's encoding**, so archives written against swift-bignum 5.x will
not decode.

## Primality

**`isPrime` is a `Bool?`, and `nil` means "not proven".** It answers only what
this package can establish, and declines to pass off a probable answer as a
certain one:

```swift
BigInt(1000003).isPrime                  // true
BigInt(1000001).isPrime                  // false, 101 * 9901
BigInt(561).isPrime                      // false -- a Carmichael number is not fooling this
BigInt(-7).isPrime                       // false, as is anything below 2
(BigInt(1) << 127 - 1).isPrime           // true  -- a Mersenne number, so exactly settled
(BigInt(1) << 300).nextPrime.isPrime     // nil   -- probably prime, unproven
```

A `false` is always available: a witness to compositeness *is* a proof, at any
size. A `true` needs one of three things — the value below 2^64, or below
3317044064679887385961981 (the last entry of [A014233], where Miller-Rabin on the
first thirteen prime bases is deterministic), or a Mersenne number, which
Lucas-Lehmer settles outright. Past all of those you get `nil`.

Because `nil` is not `false`, `if n.isPrime` will not compile. Say which reading
you want:

```swift
if n.isPrime == true { ... }              // "proven prime", unknown excluded
if n.isProbablePrime { ... }              // "no witness found", unknown included
```

### Below 2^64 there is always an answer

**`isPrime` is never `nil` for a value at or below `UInt64.max`**, since that
whole range sits inside the exhaustively verified one. If your numbers fit a
`UInt64` — or are negative, or came from an `Int` — the force unwrap cannot trap
and is the right thing to write:

```swift
BigInt(1000003).isPrime!                 // true
BigInt(1000001).isPrime!                 // false
BigInt(UInt64.max).isPrime!              // false
BigInt(Int.max).isPrime!                 // false
BigInt(-7).isPrime!                      // false
```

The certain range is in fact wider than that — `nil` does not appear until past
3317044064679887385961981, and never at all for a composite or a Mersenne number
— but `UInt64.max` is the bound worth remembering, because it is the one that
holds no matter which of the three proofs applies.

### The probable answer, when you want it

`isProbablePrime` is the [Baillie-PSW] test itself: Miller-Rabin on base 2, then
a Lucas probable-prime test. Both halves earn their place — 2047 (= 23 × 89)
passes the Miller-Rabin half, and only Lucas rejects it.

```swift
BigInt(1000003).isProbablePrime               // true
(BigInt(1) << 300).nextPrime.isProbablePrime  // true, where isPrime says nil
```

No composite is known to pass BPSW, and none below 2^64 exists — that range has
been checked exhaustively — so below 2^64 the two agree by construction. A
300-bit number takes under 2 ms.

`isSurelyPrime` gives both halves at once, which is what `isPrime` is built from:

```swift
BigInt(65537).isSurelyPrime              // (true, surely: true)
BigInt(561).isSurelyPrime                // (false, surely: true)
((BigInt(1) << 300).nextPrime).isSurelyPrime   // (true, surely: false)
```

### The pieces, separately

```swift
BigInt(2047).millerRabinTest(base: 2)    // true  -- a strong pseudoprime to base 2
BigInt(2047).isLucasProbablePrime        // false -- which is what catches it
BigInt(7).jacobiSymbol(3)                // -1
BigInt(7).jacobiSymbol(2)                //  1
BigInt(7).jacobiSymbol(7)                //  0    -- not coprime
```

`millerRabinTest(base:)` proves compositeness and never primality, so a `true`
from it means only that this base found no witness. The base is a `Self`, so it
may be as large as the number under test. `jacobiSymbol(_:)` is (i / self), and
is 0 unless `self` is odd and positive.

### Mersenne numbers

For 2^p − 1 there is an exact test, so `isMersennePrime` gives a definite answer
— and `nil` when the number is not of that form at all, which is a different
thing from `false`:

```swift
(BigInt(1) << 521 - 1).isMersennePrime   // true  -- M521
(BigInt(1) << 523 - 1).isMersennePrime   // false -- M523
BigInt(100).isMersennePrime              // nil   -- not 2^p - 1
```

The exponent is recovered from the value rather than from any word size, the
recurrence reduces by folding the high half of each square onto the low half
(2^p ≡ 1, mod 2^p − 1) instead of dividing, and a composite exponent returns
`false` without running it at all. M4423 — 1332 digits — settles in about 0.1 s.

### Walking the primes

```swift
BigInt(1000).nextPrime                   // 1009
(BigInt(1) << 64).nextPrime              // 18446744073709551629
(BigInt(1) << 64).prevPrime              // 18446744073709551557
BigInt(2).prevPrime                      // nil -- there is nothing below 2
Array(BigInt.primes.prefix(10))          // [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
```

`nextPrime` returns a value rather than an Optional, unlike the fixed-width
original these came from: arbitrary precision has no ceiling to fall off, so
there is no failure to report. `prevPrime` is still Optional, because 2 really
does have nothing below it. `primes` is an endless `Sequence`, so pair it with
`prefix` or `first(where:)`.

These search on `isProbablePrime`, not `isPrime` — a walk that read `nil` as
"composite" would step over every candidate and never come back. So above 2^64
they land on a *probable* prime; ask the result for its own `isSurelyPrime` if
that matters.

All of this lives on `BigIntegerType`, so `BigUInt` has every one of them too.
It is ported from [swift2-pons]'s `xtra_prime.swift`; the factorization half of
that file is not here. One departure: the original's `isPrime` was a plain
`Bool`, which above every deterministic bound reports "BPSW found no witness" as
though it were a fact. Here that case is `nil`.

[Baillie-PSW]: https://en.wikipedia.org/wiki/Baillie%E2%80%93PSW_primality_test
[A014233]: https://oeis.org/A014233
[swift2-pons]: https://github.com/dankogai/swift2-pons

## Random values

```swift
BigUInt.random(withMaximumWidth: 1024)      // 0 ..< 2^1024
BigUInt.random(withExactWidth: 1024)        // exactly 1024 bits, so 2^1023 ..< 2^1024
BigUInt.random(lessThan: n)                 // 0 ..< n
BigInt.random(from: -100, to: 100)          // -100 ... 100
```

Each takes an optional generator — `random(lessThan: n, using: &myGenerator)` —
and uses `SystemRandomNumberGenerator` without one. Seed your own and the
sequence is reproducible, which is what the tests do.

**`random(from:to:)` is closed: `to:` is reachable.** Swift usually reads `to:` as
excluding and `through:` as including, so this is worth knowing. Both ends of an
arbitrary-precision range are ordinary values with nothing special about either,
and "a number between these two" wants both of them.

```swift
BigInt.random(from: 0, to: 1)               // 0 or 1, never anything else
BigUInt.random(from: 5, to: 5)              // 5
```

The width forms return non-negative values on `BigInt` too: a width says how many
bits the magnitude has and nothing about a sign. Negate on a coin flip if you want
one.

**`lessThan:` and `from:to:` sample without bias.** They draw exactly as many bits
as the bound needs and draw again if the result is out of range — rejection, which
discards under half the draws, so fewer than two tries on average and no value
favoured. Scaling a draw down with `%` would be shorter and would skew the low
end: for a limit of 5, three bits give 0…7, and remainder hands 0, 1 and 2 twice
the share of 3 and 4. `RandomTests` asserts the even distribution and would catch
that.

These are on the built-in integers too, delegating like everything else:

```swift
Int.random(from: -100, to: 100)
UInt8.random(lessThan: 200)
UInt64.random(withExactWidth: 64)
Int8.random(withMaximumWidth: 100)          // traps: 100 bits is not an Int8
```

And there `random()` takes no arguments at all, meaning the whole range:

```swift
Int.random()                                // Int.min ... Int.max
UInt8.random()                              // 0 ... 255
```

It is defined as `random(from: Self.min, to: Self.max)` and *is* that call, so a
seeded generator gives the same value through either spelling. **`BigInt` and
`BigUInt` have no `random()`** — an unbounded type has no `min` or `max` for it to
mean anything against, so the no-argument form exists exactly where the type is
bounded.

A whole fixed-width range is a span of 2^bitWidth, a power of two, and a
power-of-two bound is already uniform at one bit fewer — so that path skips the
rejection step rather than throwing away half of its draws.

The standard library's `Int.random(in: 1...10)` is untouched and remains the
idiomatic spelling for a fixed-width range. These exist so generic code can say
`T.random(...)` for any integer this package touches, `BigInt` included.

attaswift spells the first three `randomInteger(...)`; see
[CAVEAT.md](CAVEAT.md#missing-the-same-capability-under-another-name).

## `over`: making fractions out of integers

Every integer here has an `over(_:)`, which is the idiomatic way to build a
rational. It reads as the fraction bar — `a.over(b)` is *a over b* — and it means
you rarely have to name a rational type:

```swift
BigInt(1).over(3)     // (1/3)   -- a BigRat
BigInt(6).over(4)     // (3/2)   -- reduced on construction
BigInt(6).over(-4)    // (-3/2)  -- the sign moves to the numerator
BigInt(1).over(0)     // (1/0)   -- infinity, no special case needed
BigInt(0).over(0)     // (0/0)   -- NaN, likewise
```

**Which rational you get is decided by the type you call it on**, so `over` is
also how you choose between growing and bounded arithmetic:

| called on | returns | grows? |
|---|---|---|
| `BigInt` | `BigRat` (`BigRational`) | yes, without bound |
| `Int` | `IntRat` (`FixedWidthRational<Int>`) | no — traps on overflow |
| `Int8`, `Int16`, `Int32`, `Int64`, `Int128` | `FixedWidthRational` over that type | no |
| a custom `RationalElement` | `Rational<Self>` | depends on the element |

```swift
1.over(3)                // (1/3), an IntRat -- 1 is an Int
Int8(1).over(2)          // (1/2), a FixedWidthRational<Int8>
Int64(3).over(9)         // (1/3), reduced, a FixedWidthRational<Int64>
BigInt(1).over(3)        // (1/3), a BigRat

1.over(3) + 1.over(6)                    // (1/2), in two Ints
BigInt(1).over(3) + BigInt(1).over(6)    // (1/2), in two BigInts that can grow
```

The three overloads that produce a fraction from an integer are on
`RationalElement` (generic, giving `Rational<Self>`), `BigInt` (giving `BigRat`)
and `FixedWidthRationalElement` (giving `FixedWidthRational<Self>`). Swift picks
the most specific one, which is why `1.over(3)` is an `IntRat` and not a
`Rational<Int>`.

`over` on a *rational* divides instead of constructing — see
[BigRat.md](BigRat.md#over-both-directions-of-the-fraction-bar) — and the whole of
the resulting type is documented there.

## BigUInt

Everything above, minus the sign. It is `BigInt.Magnitude`, and it is what
`BigFloat.RawSignificand` is.

```swift
BigUInt(1) << 128            // 340282366920938463463374607431768211456
BigUInt(1) << 128 - 1        // 340282366920938463463374607431768211455
BigUInt(255).bitWidth        // 8
BigUInt("ff", radix:16)!     // 255
BigUInt("-1")                // nil -- an unsigned type refuses a sign
```

Subtracting past zero traps, as `UInt` does. There is no `max`: the type is
unbounded, so `BigUInt.max` would not have an answer.

## On the built-in integers too

All of the above — `power`, `power(_:mod:)`, the primality family, `squareRoot`,
`greatestCommonDivisor` — is also on `Int`, `UInt`, `Int8` … `UInt64`, and
`Int128`/`UInt128` where the platform has them:

```swift
Int(2).power(10)                        // 1024
1000003.isPrime!                        // true
UInt8(200).nextPrime                    // 211
Int(1071).greatestCommonDivisor(with: 462)   // 21
Array(Int.primes.prefix(5))             // [2, 3, 5, 7, 11]
```

Each one widens to `BigInt`, works there, and converts back. That is not a
shortcut so much as the only sane way to get these onto a fixed-width type: a
modular product of two residues does not fit in a word, so a native version would
need an overflow-avoiding variant per width, and a call from a context generic
over `FixedWidthInteger` would statically pick whichever one the compiler saw.
`BigInt` has no such problem, and the only fixed-width question left is whether
the answer fits.

**When it does not, it traps** — like `*` and `+` on these types, and unlike
wrapping or clamping:

```swift
Int(2).power(62)                        // 4611686018427387904
Int(2).power(1024)                      // traps: an Int has no such number
Int8(-3).power(5)                       // traps: -243 does not fit
Int8(127).nextPrime                     // traps: 131 does not fit
Int.min.greatestCommonDivisor(with: Int.min)   // traps: the answer is 2^63
```

`BigInt(x)` is the way out of all of those, and it is one call away. Some of the
operations cannot overflow at all, and are safe at any width:

| operation | can it trap? |
|---|---|
| `power(_:mod:)` | no — the answer is bounded by a modulus that is already a `Self` |
| `squareRoot()` | no — a root is never larger than its argument |
| `prevPrime` | no — it only moves toward zero |
| `isPrime`, `isProbablePrime`, `isSurelyPrime`, `jacobiSymbol`, `millerRabinTest` | no — the answers are not `Self` |
| `power(_:)` | yes, on overflow |
| `nextPrime` | yes, if the next prime is past `Self.max` |
| `greatestCommonDivisor(with:)` | only `gcd(Int.min, Int.min)` |
| `primes` | only past `Self.max`, which needs a type no wider than `Int16` to reach |

That first row is the useful one: `power(_:mod:)` is exactly what `power(_:)`
followed by `%` cannot be.

```swift
Int(2).power(1024, mod: 1_000_000_007)  // 812734592
Int(2).power(1024) % 1_000_000_007      // traps long before the `%`
UInt8(200).power(200, mod: 251)         // 1, though 200 * 200 overflows a UInt8 twice over
```

**`isPrime!` is safe on any type of 64 bits or fewer**, since no value one of them
can hold falls outside the exhaustively verified range. A 128-bit type is the
exception — above `UInt64.max` a prime can come back `nil`.

Two small print items. The modular `power` takes its exponent generically
(`power<E: BinaryInteger>(_:mod:)`) rather than as the `Int`/`Self` pair
`BigIntegerType` uses, because when `Self` is `Int` those two are the same
signature and every call site is ambiguous. And `squareRoot()` and
`greatestCommonDivisor(with:)` already reached the *signed* built-ins through
`RationalElement`, by this same widen-and-return trick — `Int(10).squareRoot()` is
not new. Only the unsigned ones gained them, `RationalElement` being a
`SignedInteger`.

## The protocols

Three layers, so an algorithm can name "a big integer" without naming the concrete
type:

```swift
public protocol BigIntegerType : BinaryInteger, LosslessStringConvertible, Codable, Sendable {
    var isZero: Bool { get }
    func toString(radix: Int, uppercase: Bool) -> String
    init?<S: StringProtocol>(_ text: S, radix: Int)
    func squareRoot() -> Self
    func power(_ exponent: Int) -> Self
    func power(_ exponent: Int, mod modulus: Self) -> Self
    func power(_ exponent: Self, mod modulus: Self) -> Self
    func greatestCommonDivisor(with other: Self) -> Self
}

public protocol BigUIntType : BigIntegerType, UnsignedInteger {}
public protocol BigIntType  : BigIntegerType, SignedInteger where Magnitude : BigUIntType {}
```

`BigIntegerType` adds the operations `BinaryInteger` lacks; the other two say
nothing further. All of them are implemented generically in an extension, so a new
conformer gets a working version of each for free and overrides only what is worth
specializing — which is what `BigInt` and `BigUInt` do for `squareRoot()` and
`greatestCommonDivisor(with:)`. The three `power`s share a single
square-and-multiply loop, which takes the modulus as an `Optional` and reduces
after each step when it has one.
