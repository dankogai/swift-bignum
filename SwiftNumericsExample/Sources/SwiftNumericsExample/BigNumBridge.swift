//
//  BigNumBridge.swift -- reaching BigNum's own implementations without looping.
//
//  This file imports BigNum and *not* RealModule, so BigNum's names mean BigNum's
//  here.  That alone is not enough, and the reason is worth spelling out.
//
//  NumericsConformance.swift declares `sqrt`, `exp10`, `reciprocal` and
//  `signGamma` directly on `BigRat` and `BigFloat`, because each has a default
//  implementation in *both* protocol hierarchies and a requirement with two
//  equally good witnesses is unsatisfied.  A member on the concrete type outranks
//  a protocol-extension default -- which is what makes it work, and also what
//  makes the obvious delegation a trap: those four are requirements of BigNum's
//  `ElementaryFunctions`/`RealFunctions` too, so the concrete member becomes
//  *BigNum's* witness as well.  `BigRat.sqrt(x)` from here would land back on the
//  witness that called it.  It compiles, and it recurses until the stack ends.
//
//  So nothing below calls a one-argument form.  BigNum gives every function a
//  `precision:`-taking twin, and those are ordinary extension members rather than
//  protocol requirements -- a different signature, no dispatch, no way back to the
//  witness.  `sqrt(x)` in BigNum is exactly `sqrt(x, precision: Self.precision,
//  debug: false)` (ElementaryFunctions.swift:927), which is what these call, so
//  the behaviour is the library's own and not a reimplementation of it.
//
import BigNum

/// √x, at BigNum's default precision -- the `precision:` overload, so this cannot
/// resolve to the one-argument witness that calls it.
@inline(__always) func bignum_sqrt<T:BigFloatingPoint>(_ x: T) -> T {
    return T.sqrt(x, precision: T.precision, debug: false)
}

/// 10^x.  BigNum's `exp10` is `pow(10, x)` and has no `precision:` twin of its
/// own, so this goes to `pow`'s -- which we do not declare, so it is unambiguous.
@inline(__always) func bignum_exp10<T:BigFloatingPoint>(_ x: T) -> T {
    return T.pow(10, x, precision: T.precision, debug: false)
}

/// The sign of Γ(x).
///
/// The one member here that *is* reimplemented, because BigNum's lives only as a
/// default on its `Real` and has no differently-shaped twin to call.  Kept
/// equivalent to Real.swift:71: Γ is negative exactly between the odd negative
/// integers, and at a negative integer it has a pole rather than a sign change.
/// The parity test avoids `radix` and `addingProduct`, so it reads the same for a
/// rational as for a float.
@inline(__always) func bignum_signGamma<T:FloatingPoint>(_ x: T) -> FloatingPointSign {
    if x >= 0 { return .plus }
    let trunc = x.rounded(.towardZero)
    if x == trunc { return .plus }              // a pole, not a sign change
    let half = (trunc / 2).rounded(.towardZero)
    return half * 2 == trunc ? .minus : .plus
}

/// a/b for a rational, by the method behind BigNum's own `/`
/// (`RationalType.over(_:)`), since `/` itself is declared on the concrete type in
/// NumericsConformance.swift and would come straight back here.
@inline(__always) func bignum_divide(_ a: BigRat, _ b: BigRat) -> BigRat {
    return a.over(b)
}
