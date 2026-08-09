# BigRat

An exact rational: a `BigInt` numerator over a `BigInt` denominator, always
reduced. `BigRat` is a `FloatingPoint` and a `Real`, so it behaves like a
floating-point type — but nothing it does rounds unless you ask.

```swift
import BigNum

BigRat(1,3) + BigRat(1,3) + BigRat(1,3) == 1        // true
0.1 + 0.2 == 0.3                                     // false, for a Double
BigRat(1,10) + BigRat(2,10) == BigRat(3,10)          // true
```

`BigRat` is a typealias for `BigRational`. Both names work.

## Exact means exact

Every `+ - * /` is exact, and the numerator and denominator grow to whatever size
that requires. This is the point of the type, and also the thing to watch: a long
chain of exact arithmetic produces enormous fractions. `truncate(width:)` is how
you cut one back down — see [Precision](#precision) below.

```swift
BigRat(1,3) * 3            // (1/1)
BigRat(2,3) / BigRat(4,9)  // (3/2)
BigRat(1,3).reciprocal!    // (3/1)
```

Compare with [`BigFloat`](BigFloat.md), which keeps a fixed number of significant
bits and rounds instead:

```swift
BigRat(1)/BigRat(3)     * 3 == 1    // true
BigFloat(1)/BigFloat(3) * 3 == 1    // false
```

## `over`: both directions of the fraction bar

The idiomatic way to make a rational is `over(_:)`, called on the *integers*:

```swift
BigInt(1).over(3)             // (1/3)
BigInt(6).over(4)             // (3/2)  -- reduced on construction
BigInt(6).over(-4)            // (-3/2) -- the sign moves to the numerator
```

It reads as the fraction bar: `a.over(b)` is *a over b*. Which rational you get
is decided by what you call it on, so `over` doubles as the way you choose between
unbounded and bounded arithmetic:

```swift
BigInt(1).over(3)             // (1/3), a BigRat -- grows without bound
1.over(3)                     // (1/3), an IntRat -- two Ints, traps on overflow
Int8(1).over(2)               // (1/2), a FixedWidthRational<Int8>
Int64(3).over(9)              // (1/3), a FixedWidthRational<Int64>

1.over(3) + 1.over(6)                    // (1/2), in Ints
BigInt(1).over(3) + BigInt(1).over(6)    // (1/2), in BigInts
```

Because a `BigRat` *is* its fraction, the special values need no special case —
they fall out of what you hand `over`:

```swift
BigInt(1).over(0)             // (1/0)  -- infinity
BigInt(0).over(0)             // (0/0)  -- NaN
BigInt(0).over(5)             // (0/1)  -- zero, normalized
```

Called on a rational instead of an integer, `over` **divides** — the same reading
of the bar, one level up:

```swift
BigRat(1,2).over(BigRat(1,3))     // (3/2), the same as `/`
BigRat(1,2).over(BigInt(3))       // (1/6), dividing by a bare numerator
IntRat(1,2).over(3)               // (1/6), same for the fixed-width form
```

So `x.over(y)` builds a fraction when `x` is an integer and divides when `x` is
already one. Both are "x over y"; the difference is only what `x` was.

## Construction

```swift
BigRat(1, 3)                  // (1/3)  -- the direct form
BigInt(1).over(3)             // (1/3)  -- the same thing, via `over`
BigRat(6, 4)                  // (3/2)  -- reduced on construction
BigRat(6, -4)                 // (-3/2) -- the sign moves to the numerator
BigRat(-6, -4)                // (3/2)
let q: BigRat = 1             // integer and float literals
BigRat(0.5)                   // (1/2)
BigRat(0.1)                   // (3602879701896397/36028797018963968)
```

That last one is worth staring at. `BigRat(0.1)` is the *exact* value of the
`Double` 0.1, which is not one tenth. Converting from a binary floating-point
value gives you exactly what that value was, not what it was printed as. Use
`BigRat(1, 10)` for one tenth.

Numerator and denominator are readable, and settable:

```swift
BigRat(1,3).num          // 1
BigRat(1,3).den          // 3
BigRat(1,3).numerator    // 1  -- FloatingPoint-ish spelling of the same thing
```

## NaN, infinity, and the two zeros

`BigRat` gets `FloatingPoint`'s special values out of the fraction itself, with no
extra storage and no sentinels:

| value | `num`/`den` |
|---|---|
| NaN | `(+0/0)` |
| +infinity | `(+1/0)` |
| -infinity | `(-1/0)` |
| +0 | `(+0/1)` |
| -0 | `(+0/-1)` |

```swift
BigRat(0,0).isNaN            // true
BigRat(1,0)                  // +infinity
BigRat.nan == BigRat.nan     // false -- IEEE says so
(-BigRat.zero).sign          // minus
BigRat.infinity > 1          // true
```

A negative zero is the only value whose sign lives on the denominator, which is
why `toString(.fraction)` is the format that can still show it — `(+0/-1)`.

> **Known gap.** `RationalType.init(_:_:)` normalizes the sign onto the numerator,
> where a zero's sign has nowhere to go, so `BigRat(BigInt(0), BigInt(-1))` comes
> back `+0` even though `BigRat(num:0, den:-1)` is `-0`. The visible consequence
> is that `atan2(-0, x)` returns `+0` instead of `-0` for finite positive `x`;
> `ElementaryFunctionsTests` records it as a known issue.

## Mixed numbers, rounding and conversions

```swift
BigRat(22,7).toMixed()          // .0 == BigInt(3),  .1 == BigRat(1,7)
BigRat(-22,7).toMixed()         // .0 == BigInt(-3), .1 == BigRat(-1,7)
BigRat(22,7) % 1                // (1/7)
BigRat(22,7).rounded()          // (3/1)
BigRat(22,7).rounded(.down)     // (3/1)
BigRat(-22,7).rounded(.towardZero)  // (-3/1)

BigRat(22,7).toDouble()         // 3.142857142857143
BigRat(22,7).toBigFloat()       // 3.14285714285714285714285714285714285714301
BigRat(22,7).toIntRat()         // an IntRat, truncated to fit two Ints
```

`toDouble()` handles the case that trips up the naive `Double(num)/Double(den)`:
both sides can sit far outside `Double`'s range while their ratio is perfectly
ordinary. π/4 held to 1151 bits, for instance, would give `inf/inf` — so the
conversion shifts both down together first.

`exponent` and `significand` decompose in radix 2, normalized to `[1,2)`:

```swift
BigRat(22,7).exponent       // 1
BigRat(22,7).significand    // (11/7)
BigRat(22,7).decomposed     // (sign, exponent, significand) in one go
```

## Precision

`BigRat`'s arithmetic never rounds, so `precision` only enters where a result is
irrational and an answer has to be chosen — `sqrt`, `exp`, `log`, the
trigonometrics — or where you explicitly truncate. The unit is **bits**.

```swift
BigRat.precision                    // 128, the default for omitted precision:
BigRat.sqrt(2, precision:32)        // +1.41421356215141713619
BigRat.sqrt(2, precision:256)       // +1.414213562373095048801688724209698078569671875376948073176679737990732478462102
BigRat.getEpsilon(precision:16)     // (1/65536)
```

`truncate(width:)` and `truncated(width:round:)` cut a fraction back to a
power-of-two denominator, which is how you stop one growing without bound:

```swift
BigRat(1,3).truncated(width:8)                    // (85/256)
BigRat(1,3).truncated(width:8).toString()         // +0.33203125
BigRat.sqrt(2).num.bitWidth                       // 129
```

Rounding follows `roundingRule`, `.toNearestOrAwayFromZero` by default, and every
`FloatingPointRoundingRule` is honoured.

## Elementary functions

`BigRat` conforms to `Real`, so all of `ElementaryFunctions` and `RealFunctions`
is there. Each also has a `precision:`-taking form:

```swift
BigRat.pi                       // +3.141592653589793238462643383279502884195
BigRat.E()                      // +2.718281828459045235360287471352662497759
BigRat.LN2()                    // +0.6931471805599453094172321214581765680748
BigRat.exp(1)
BigRat.log(2)
BigRat.sin(1)
BigRat.pow(2, BigRat(1,2))      // +1.414213562373095048801688724209698078569
BigRat.hypot(3,4)               // (5/1)  -- exact when it can be
BigRat.atan2(y:1,x:1)           // +0.7853981633974483096156608458198757210488
BigRat(2).power(10)             // (1024/1) -- integer exponent, exact
```

√2, e, log 2, log 10 and π/4 are memoized per precision, so asking twice at the
same precision is free. The memo is a plain `static var`, which is why
`ElementaryFunctionsTests` is `.serialized`.

## Strings

```swift
let q = BigRat.sqrt(2)
q.toString()                        // +1.414213562373095048801688724209698078569
q.toString(.fraction)               // (+240615969168004511545033772477625056927/170141183460469231731687303715884105728)
q.toString(.exponent)               // +0x1.6a09e667f3bcc908b2fb1366ea957d3ep0
q.toString(.fraction, radix:16)     // (+0x2d413cccfe779921.../0x2000...)
q.debugDescription                  // the same as .fraction in radix 16
q.description                       // (num/den), unsigned-normalized
```

`Codable` is synthesized, so a `BigRat` encodes as `num` and `den`, each a
base-16 string.

## The fixed-width rationals

The same arithmetic over fixed-width integers, for when you want a rational that
cannot grow:

```swift
1.over(3)                    // (1/3), a FixedWidthRational<Int> -- the usual way in
IntRat(1,3)                  // the same thing, naming the type
IntRat(1,3) + IntRat(1,6)    // (1/2)
IntRat.max                   // (9223372036854775807/1)
IntRat(1,3).toDouble()       // 0.3333333333333333
1.over(3).toBigRat()         // widen when you need room
Rational<BigInt>(1,3)        // the unconstrained generic form
```

`IntRat` is `FixedWidthRational<Int>`. `FixedWidthRational` works over any
`FixedWidthRationalElement`, which `Int`, `Int8`, `Int16`, `Int32`, `Int64` and —
where the platform has it — `Int128` all conform to.

These **do** overflow: a numerator or denominator that will not fit traps like any
fixed-width arithmetic. They exist for bounded storage and predictable cost, not
for exactness at any size. `toBigRat()` widens one when you need room.

## The protocol stack

```swift
public protocol RationalType : CustomStringConvertible, FloatingPoint, ExpressibleByFloatLiteral {
    associatedtype Element : RationalElement
    associatedtype IntType : RationalElement
    var num: Element { get set }
    var den: Element { get set }
    init(num: Element, den: Element)
}

public protocol BigRationalType : RationalType & BigFloatingPoint {}
public protocol FixedWidthRationalType : RationalType, CustomDebugStringConvertible, Codable
  where Element : FixedWidthRationalElement {}
```

Almost all of the behaviour lives in an extension on `RationalType`, so
`BigRational`, `Rational<I>` and `FixedWidthRational<I>` share one implementation
of the arithmetic, the comparisons and the `FloatingPoint` conformance.
