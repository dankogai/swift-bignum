# SwiftComplexExample

`Complex<BigRat>` and `Complex<BigFloat>`, using [dankogai/swift-complex] for the
complex part and [swift-bignum](..) for the real part.

```bash
cd SwiftComplexExample && swift test
```

The same exercise as [SwiftNumericsExample](../SwiftNumericsExample/), against a
different `Complex`. Comparing the two is the point: what it takes to be somebody
else's real part depends entirely on how that somebody declares their protocol.

## The whole conformance

```swift
import BigNum
import Complex

extension BigRat: RMath {}
extension BigFloat: RMath {}
```

Empty, and — unlike the swift-numerics one — empty at the first attempt.
`swift-complex`'s `RMath` declares the elementary functions as **requirements** and
deliberately supplies no defaults for the ones swift-bignum already has, so there
is nothing to tie with: each requirement has exactly one candidate, and it is
BigNum's. No bridge file, no hand-written witnesses, no recursion to avoid.

## Precision is a call-site decision

`RMath` declares the `precision:debug:` forms as requirements too, not as
conveniences, which is what lets generic code inside `Complex` dispatch to
arbitrary precision instead of binding a forwarder that quietly drops the argument:

```swift
Complex<BigFloat>.exp(Complex<BigFloat>(0, BigFloat.PI(precision: 512)),
                      precision: 512, debug: false)
```

How far `exp(iπ)` lands from -1, as `|Re + 1| + |Im|`:

| bits | miss |
|---:|---:|
| 128 | 2.10e-39 |
| 256 | 1.28e-77 |
| 512 | 2.19e-155 |
| 1024 | 9.17e-309 — a *subnormal* `Double` |
| `Complex<Double>` | 1.22e-16 |

Reporting the error as a `Double` runs out before the arithmetic does. No global is
touched to get any of this, which is the practical difference from
[SwiftNumericsExample](../SwiftNumericsExample/): swift-numerics' `Complex` has no
precision parameter, so it runs at `BigFloat.precision` — a mutable `static var`
that Swift 6 language mode will not even let you read.

Division is exact over `BigRat` in both examples, `(1+2i)/(3+4i)` being `(11+2i)/25`
exactly, because that is plain arithmetic rather than an elementary function.

## This pins a branch, on purpose

`Package.swift` depends on swift-complex's **`main`**, because `RMath` is
unreleased. A branch pin drifts; if a release containing `RMath` appears, point at
that tag instead.

The reason it is not on tag 5.0.0 is worth stating plainly. That tag spells the
protocol `FloatingPointMath`, whose only requirements are `init(_:Double)` and
`asDouble` — every function comes as an extension default routed through
`asDouble`. Conforming to it compiles, and then:

```
Complex<BigRat>.exp(iπ)    im = 1.2246467991473532e-16
Complex<Double>.exp(iπ)    im = 1.2246467991473532e-16     ← bit-for-bit identical
```

The arbitrary precision is gone. Not an error, not a warning: generic code inside
`Complex` can only see the Double-routed default, so it is the one that runs. That
tag also makes about two dozen function names ambiguous at any call site importing
both modules — `BigRat.exp(1)` does not compile.

`transcendentalsUseBigNumAndNotDouble` exists to catch a regression to that
behaviour: it asserts the 128-bit error is under 1e-38 *and* at least twenty orders
of magnitude better than `Double`'s, so 1.22e-16 fails it twice.

## The tests

Eight, from a clean `.build`: that the transcendentals are BigNum's and not
`Double`'s, the precision ladder above, that the contested names resolve
(`BigRat.exp`, `BigFloat.sqrt`, `BigRat.hypot`, `BigFloat.atan2`, and
`Double.exp`/`Double.sqrt` beside them), exact `Complex<BigRat>` division,
arithmetic over both types, `√i`, and agreement with `Double` wherever a `Double`
is exact.

[dankogai/swift-complex]: https://github.com/dankogai/swift-complex
