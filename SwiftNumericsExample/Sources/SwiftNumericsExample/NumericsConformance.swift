//
//  NumericsConformance.swift -- BigRat and BigFloat as swift-numerics `Real`s, so
//  that `Complex<BigRat>` and `Complex<BigFloat>` work.
//
//  `Complex<RealType>` requires `RealType: RealModule.Real`, and BigNum's types
//  conform to BigNum's own `Real` instead -- same requirement set, different
//  protocol.  Every method swift-numerics asks for is already there under the same
//  name with the same signature; the compiler says so, in as many words:
//
//      note: candidate exactly matches
//
//  What it says next is the problem:
//
//      error: type 'BigFloat' does not conform to protocol 'AlgebraicField'
//      note: multiple matching properties named 'reciprocal' with type 'BigFloat?'
//
//  Four members -- `sqrt`, `exp10`, `reciprocal`, `signGamma` -- have a default in
//  each hierarchy, plus `/` for `BigRat` alone, whose `/` comes from a protocol
//  extension where `BigFloat`'s is on the struct.  Two equally specific candidates
//  do not overload a requirement, they leave it unsatisfied.  A member declared on
//  the concrete type outranks both, which is why those five are written out below;
//  the other thirty-odd requirements need nothing.  See BigNumBridge.swift for why
//  their bodies do not simply call BigNum by name.
//
//  This lives in the example package rather than in BigNum on purpose.  BigNum's
//  manifest has no dependencies -- Real.swift exists precisely so that it needs
//  none -- and taking on swift-numerics to hand a conformance back would undo that.
//  A retroactive conformance costs the library nothing, and anyone wanting
//  `Complex` over these types can copy these two files.
//
import BigNum
import RealModule

// MARK: - BigRat

extension BigRat {
    /// √x.  The static spelling both `Real`s require; here to outrank the two
    /// defaults rather than to add anything.
    public static func sqrt(_ x: BigRat) -> BigRat { return bignum_sqrt(x) }
    /// 10^x
    public static func exp10(_ x: BigRat) -> BigRat { return bignum_exp10(x) }
    /// The sign of Γ(x), which `logGamma` drops by taking |Γ|.
    public static func signGamma(_ x: BigRat) -> FloatingPointSign {
        return bignum_signGamma(x)
    }
    /// 1/self, or nil when that is not representable -- so a caller may substitute
    /// `x * y.reciprocal!` for `x / y` without losing accuracy.
    public var reciprocal: BigRat? {
        let recip = 1/self
        if recip.isNormal || isZero || !isFinite { return recip }
        return nil
    }
    /// a/b.  `BigFloat` needs no equivalent: its `/` is declared on the struct and
    /// already outranks `AlgebraicField`'s default, where a rational's comes from
    /// `extension RationalType` and merely ties with it.
    public static func / (a: BigRat, b: BigRat) -> BigRat { return bignum_divide(a, b) }
}

extension BigRat: RealModule.Real {}

// MARK: - BigFloat

extension BigFloat {
    /// √x -- see `BigRat.sqrt(_:)` for why this is spelled out.
    public static func sqrt(_ x: BigFloat) -> BigFloat { return bignum_sqrt(x) }
    /// 10^x
    public static func exp10(_ x: BigFloat) -> BigFloat { return bignum_exp10(x) }
    /// The sign of Γ(x).
    public static func signGamma(_ x: BigFloat) -> FloatingPointSign {
        return bignum_signGamma(x)
    }
    /// 1/self, or nil when that is not representable.
    public var reciprocal: BigFloat? {
        let recip = 1/self
        if recip.isNormal || isZero || !isFinite { return recip }
        return nil
    }
}

extension BigFloat: RealModule.Real {}
