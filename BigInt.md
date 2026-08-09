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
