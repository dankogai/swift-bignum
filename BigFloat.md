# BigFloat

Binary floating point with an arbitrary mantissa: a `BigInt` significand and an
`Int` power-of-two scale. `BigFloat` is a `FloatingPoint` and a `Real`, and it is
the type to reach for when you want a lot of digits but not an unbounded number of
them.

```swift
import BigNum

BigFloat.sqrt(2)                    // 1.414213562373095048801688724209698078569
BigFloat.exp(1, precision:256)      // e to 256 bits
BigFloat.exp(1000)                  // 197007111401704699388887 ... and 411 more digits
Double.exp(1000)                    // inf
```

## Representation

Two stored properties:

```swift
public var scale: Int          // a power of two
public var mantissa: BigInt    // the significand, sign included
```

The value is `mantissa × 2^scale`. The initializer normalizes by moving trailing
zero bits out of the mantissa and into the scale, so a value has one canonical
form:

```swift
BigFloat(scale:0, mantissa:3).scale       // 0
BigFloat(scale:0, mantissa:4).scale       // 2   -- the two trailing zeros moved
BigFloat(scale:0, mantissa:4).mantissa    // 1
BigFloat(1).mantissa                      // 1
BigFloat(1).scale                         // 0
BigFloat(8).scale                         // 3
```

NaN, the infinities and the two zeros are encoded in `scale`/`mantissa`
combinations that no finite value can occupy — `scale == Int.max` with mantissa
+1, -1 and 0 respectively, and `scale == -Int.max-1` for negative zero. You never
have to know that, but it explains why `scale` is not meaningful for a special
value.

## BigFloat versus BigRat

Both carry arbitrary precision; they differ in what happens to `/`.

```swift
BigRat(1)/BigRat(3)     * 3 == 1    // true  -- exact, the denominator just grows
BigFloat(1)/BigFloat(3) * 3 == 1    // false -- rounded to `precision` bits
```

A `BigRat` never rounds and never stops growing. A `BigFloat` rounds every
division to `precision` significant bits, so its storage stays bounded and its
cost stays predictable. `+`, `-` and `*` are exact in both — it is only division
(and the irrational functions) where the two part ways.

```swift
(BigFloat(1)/BigFloat(3)).mantissa.bitWidth               // 130 -- precision 128 plus guard bits
BigFloat(1).divided(by: BigFloat(3), precision:16)       // 0.333332061767578125
BigFloat(1).divided(by: BigFloat(3), precision:16).mantissa.bitWidth   // 18
```

Conversion between them is lossless in one direction and rounding in the other:

```swift
BigFloat(0.1).toBigRat().toString(.fraction)   // (+3602879701896397/36028797018963968)
BigFloat(BigRat(1,3))                          // 0.3333333333333333333333333333333333333331
BigFloat(BigRat(1,3), precision:16)            // 0.333332061767578125
```

Every `BigFloat` is exactly a `BigRat` (its denominator is a power of two), so
`toBigRat()` loses nothing. Going the other way has to choose a precision.

That makes `over` a convenient way into a `BigFloat` from two integers: build the
exact fraction, then round it once, where you can see it happening.

```swift
BigFloat(BigInt(1).over(3))                  // one third, to `precision` bits
BigFloat(BigInt(1).over(3), precision:16)    // 0.333332061767578125
BigFloat(BigInt(355).over(113))              // 355/113, rounded once
```

## Construction

```swift
BigFloat(1)                  // from any BinaryInteger
BigFloat(0.5)                // from any BinaryFloatingPoint, exactly
BigFloat(0.1)                // 0.10000000000000000555 -- the Double's real value
let x: BigFloat = 1.5        // integer and float literals
BigFloat(scale:-1, mantissa:3)               // 1.5
BigFloat(BigRat(1,3), precision:16)          // from a BigRat, at a chosen precision
```

As with `BigRat`, `BigFloat(0.1)` is the exact value of the `Double` 0.1, not one
tenth. `BigFloat(BigRat(1,10))` is one tenth rounded to `precision` bits.

### From a string

`init?(_:radix:)` takes decimal, hex, octal and binary, with an optional exponent —
`p` for a power of two after a hex significand, `e` for a power of ten after a
decimal one:

```swift
BigFloat("1.5")!            // 1.5
BigFloat("3.14159")!
BigFloat("0x1.8p1")!        // 3.0
BigFloat("0x1p-4")!         // 0.0625
BigFloat("0b1011")!         // 11.0
BigFloat("0o17")!           // 15.0
BigFloat("1.5e10")!         // 15000000000.0
BigFloat("1.8p1", radix:16)!    // 3.0 -- the radix argument stands in for a prefix
BigFloat("-0")!.sign        // minus, the sign of a zero survives
```

It is genuinely failable — malformed text returns `nil` rather than trapping:

```swift
BigFloat("")            // nil
BigFloat("+")           // nil
BigFloat("nonsense")    // nil
BigFloat("1e")          // nil
BigFloat("0x1pz")       // nil
BigFloat("1.2.3")       // nil
BigFloat("--1")         // nil
```

## Precision and rounding

Two statics set the defaults, and every lossy operation takes an override:

```swift
BigFloat.precision              // 128
BigFloat.roundingRule           // toNearestOrAwayFromZero

BigFloat.sqrt(2)                // 1.414213562373095048801688724209698078569
BigFloat.sqrt(2, precision:32)  // 1.41421356215141713619
BigFloat.sqrt(2, precision:256) // 1.414213562373095048801688724209698078569671875376948073176679737990732478462102

BigFloat.precision = 256        // move the default
```

`precision` is in bits. The 32-bit answer above is the exact decimal expansion of a
value accurate to only 32 bits, so it parts company with √2 after about ten
digits — precision bounds the error, not the digits printed.

Division and remainder take precision and a rounding rule explicitly:

```swift
BigFloat(22).divided(by: BigFloat(7))                        // 3.14285714285714285714285714285714285714301
BigFloat(22).divided(by: BigFloat(7), precision:16, round:.down)
BigFloat(22).remainder(dividingBy: BigFloat(7))              // 1.0
BigFloat(22) % BigFloat(7)                                   // 1.0
BigFloat.getEpsilon(precision:16)                            // 0.0000152587890625
```

`expLimit` bounds the exponential functions: an argument past `+expLimit` gives
infinity and one below `-expLimit` gives zero, rather than running forever. It
starts at `Int16.max`.

### Truncation

`truncate(width:round:)` throws away low mantissa bits in place, and
`truncated(width:round:)` returns a copy. This is how you cut a value that has
accumulated more bits than you need:

```swift
BigFloat.sqrt(2).mantissa.bitWidth                    // 129
BigFloat.sqrt(2).truncated(width:16)                  // 1.414215087890625
BigFloat.sqrt(2).truncated(width:16).debugDescription // +0x1.6a0ap0
```

## Equality and identity

`==` is IEEE equality, so NaN is not equal to itself and the two zeros are equal to
each other. `===` compares the representation:

```swift
BigFloat(0) == -BigFloat(0)      // true   -- IEEE
BigFloat(0) === -BigFloat(0)     // false  -- different representations
BigFloat.nan == BigFloat.nan     // false
BigFloat.nan === BigFloat.nan    // true
(-BigFloat(0)).sign              // minus
```

`isIdentical(to:)` is the spelled-out form of `===`.

## Specials

```swift
BigFloat.nan                          // nan
BigFloat.infinity                     // infinity
-BigFloat.infinity                    // -infinity
BigFloat.zero.debugDescription        // +0.0p0
BigFloat.negativeZero.debugDescription // -0.0p0
BigFloat(1)/BigFloat(0)               // infinity
BigFloat(0)/BigFloat(0)               // nan
```

## Elementary functions

All of `ElementaryFunctions` and `RealFunctions`, each with a `precision:`-taking
form alongside the fixed-arity one the protocol requires:

```swift
BigFloat.pi                     // 3.141592653589793238462643383279502884195
BigFloat.log(2)                 // 0.6931471805599453094172321214581765680748
BigFloat.sin(1)
BigFloat.atan2(y:1, x:1) * 4    // 3.141592653589793238462643383279502884195
BigFloat.cbrt(27)               // 3.0
BigFloat.erf(1)
BigFloat.gamma(BigFloat(0.5))    // ~sqrt(pi)
BigFloat(2).power(BigInt(100))  // 1267650600228229401496703205376.0
BigFloat.sqrt(2, precision:1024)
```

Because there is no overflow until the exponent itself runs out, these keep
answering where `Double` gives up:

```swift
Double.exp(1000)      // inf
BigFloat.exp(1000)    // 197007111401704699388887...
```

## Mixed numbers and rounding

```swift
BigFloat.sqrt(2).toMixed()      // (1, 0.414213562373095048801688724209698078569)
BigFloat.sqrt(2).rounded()      // 1.0
BigFloat.sqrt(2).toMixed().0    // 1, as a BigInt
```

## Strings

```swift
let x = BigFloat.sqrt(2)
x.toString()                 // +1.414213562373095048801688724209698078569
x.toString(.fraction)        // as a ratio -- BigFloat's denominator is a power of two
x.toString(.exponent)        // +0x1.6a09e667f3bcc908b2fb1366ea957d3ep0
x.description                // 1.414213562373095048801688724209698078569  -- no leading +
x.debugDescription           // the .exponent form
String(x, radix:16)          // the .point form in hex
```

A `BigFloat` debugs as significand-and-exponent because that is how it is stored.
See the [README](README.md#strings) for the format rules.

## Codable

Synthesized from `scale` and `mantissa`, so a `BigFloat` encodes as an `Int` and a
base-16 `BigInt` string.
