# SwiftNumericsExample

`Complex<BigRat>` and `Complex<BigFloat>`, using [apple/swift-numerics] for the
complex part and [swift-bignum](..) for the real part.

```bash
cd SwiftNumericsExample && swift test
```

A package of its own, so that swift-bignum's own manifest keeps fetching nothing —
SwiftPM resolves every declared dependency whether the target using it is being
built or not.

## The whole conformance

```swift
import BigNum
import RealModule

extension BigRat: RealModule.Real {}
extension BigFloat: RealModule.Real {}
```

That is it. `Complex<RealType>` wants `RealModule.Real`, and BigNum's types conform
to BigNum's *own* `Real` — a deliberately separate protocol with the same
requirement set, so that the library needs no dependency. Every method
swift-numerics asks for is already there under the same name and signature; the
compiler says so, in as many words: `note: candidate exactly matches`.

## What it buys you

**Division that is exact.** `(1+2i)/(3+4i)` is `(11+2i)/25`, and 25 is not a power
of two, so no binary float lands on either component:

```swift
let q = Complex<BigRat>(1, 2) / Complex<BigRat>(3, 4)
q.real == BigRat(11, 25)                    // true — the number, not a rounding
q.imag == BigRat(2, 25)                     // true
q * Complex<BigRat>(3, 4) == Complex<BigRat>(1, 2)   // true — it multiplies back
```

**Transcendentals with room to spare.** `exp(iπ)` reaches all the way down through
`cos` and `sin` to `ATAN1`:

| | `Re + 1` | `Im` |
|---|---:|---:|
| `Complex<BigFloat>` | 1.09e-39 | 1.01e-39 |
| `Complex<BigRat>` | 1.09e-39 | 1.01e-39 |
| `Complex<Double>` | 0 | 1.22e-16 |

`Double`'s imaginary part cannot be closer than that; `sin(π_double)` is 1.22e-16
away from zero and there are no bits left to fix it.

## Two things worth knowing before you copy this

**Precision is stuck at whatever `BigFloat.precision` says.** swift-numerics'
`Complex` has no `precision:` parameter, and under Swift 6 language mode
`BigFloat.precision` cannot even be *read*, let alone set — it is a mutable
`static var`, and the error hides inside `#expect`'s macro expansion. So this
example runs at the default 128 bits. [SwiftComplexExample](../SwiftComplexExample/)
does not have that limitation, because its functions take the width per call.

**`BigNum.Real` cannot be spelled.** `Sources/BigNum/BigNum.swift` declares
`public class BigNum {}`, so the module-qualified name resolves to that class's
member types:

```
error: 'Real' is not a member type of class 'BigNum.BigNum'
```

`RealModule.Real` qualifies fine; only BigNum's side is unreachable that way. If
you need to name it in a file that imports both, make a typealias in a file that
imports only BigNum, where the bare name is unambiguous.

## Why the conformance is empty, when it did not start that way

Four members — `sqrt`, `exp10`, `reciprocal`, `signGamma` — used to have a default
implementation in *both* hierarchies, plus `/` for `BigRat`. Neither protocol
refines the other, so nothing broke the tie, and a requirement with two equally
good witnesses is unsatisfied rather than overloaded:

```
error: type 'BigFloat' does not conform to protocol 'AlgebraicField'
note: multiple matching properties named 'reciprocal' with type 'BigFloat?'
```

Those five had to be written out here, forwarding through a second file that
imported only BigNum — because declaring `sqrt` on `BigFloat` makes it BigNum's
witness too, so the obvious body called itself, compiled, and recursed until the
stack ended.

BigNum now declares them on its concrete types, where a member outranks any
protocol-extension default. See the end of
[Real.swift](../Sources/BigNum/Real.swift).

## The tests

Eleven of them, and the ones that earn their keep are the awkward cases: that the
five contested members resolve and agree with BigNum, that `Complex<BigRat>`
division is exact where `Double`'s is not, and that `BigFloat`'s `==` compares
numbers rather than storage — which is a bug this exercise found and BigNum has
since fixed.

[apple/swift-numerics]: https://github.com/apple/swift-numerics
