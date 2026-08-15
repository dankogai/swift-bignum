//
//  Real.swift -- a thin, local stand-in for apple/swift-numerics' RealModule.
//
//  BigNum only ever needed four protocols out of swift-numerics -- `Real` and
//  the three it inherits -- so it carried the whole package (plus its
//  `_NumericsShims` C target) for a handful of declarations.  Apple's official
//  `BigInt` never landed there, and `Real` itself has been stable since 1.0, so
//  the dependency bought nothing that ~200 lines cannot.
//
//  The requirement sets are deliberately identical to RealModule's, so
//  `BigFloatingPoint` conforms exactly as before and code written against
//  swift-numerics keeps compiling.  What is *not* reproduced is the parts BigNum
//  never used: `Complex`, `Quaternion`, `ApproximateEquality`, augmented
//  arithmetic, and the `_relaxedAdd`/`_relaxedMul`/`_mulAdd` optimizer hooks.
//
//  This file has `Real`, `AlgebraicField` and `Double`'s conformance; the two
//  protocols in between -- `ElementaryFunctions` and `RealFunctions` -- are in
//  ElementaryFunctions.swift, beside the arbitrary-precision implementations
//  that satisfy them.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import CRT
#endif

///
/// A field with (approximate) division -- the numeric floor `Real` needs.
///
public protocol AlgebraicField : SignedNumeric where Magnitude : AlgebraicField {
    /// Replaces `a` with the (approximate) quotient `a/b`.
    static func /=(a: inout Self, b: Self)
    /// The (approximate) quotient `a/b`.
    static func /(a: Self, b: Self) -> Self
    /// The (approximate) reciprocal of `self`, or `nil` when it is not
    /// representable.
    ///
    /// Note that `.zero.reciprocal` is *not* `nil` for a type that has an
    /// `.infinity`, which includes every `Real` here.
    var reciprocal: Self? { get }
}

///
/// A real number, as far as this package is concerned.
///
public protocol Real : FloatingPoint, RealFunctions, AlgebraicField {}

extension Real {
    /// 10^x, for types that would rather not special-case it
    public static func exp10(_ x: Self) -> Self {
        return pow(10, x)
    }
    /// √x, which `FloatingPoint` already knows how to do
    public static func sqrt(_ x: Self) -> Self {
        return x.squareRoot()
    }
    /// Rejects the reciprocals that overflowed or went subnormal, so callers may
    /// substitute `x * y.reciprocal!` for `x / y` without losing accuracy.
    public var reciprocal: Self? {
        let recip = 1/self
        if recip.isNormal || isZero || !isFinite { return recip }
        return nil
    }
    /// Γ is negative exactly between the odd negative integers, and `logGamma`
    /// cannot say so because it takes the magnitude.
    public static func signGamma(_ x: Self) -> FloatingPointSign {
        if x >= 0 { return .plus }
        let trunc = x.rounded(.towardZero)
        if x == trunc { return .plus }  // a pole, not a sign change
        return trunc.isEven ? .minus : .plus
    }
    private var isEven: Bool {
        let half = self/2
        return Self.radix == 2 ? half == half.rounded(.towardZero)
          : self.addingProduct(-2, half.rounded(.towardZero)) == 0
    }
}

//
// Double's conformance.  These are file-scope wrappers on purpose: inside
// `extension Double` a bare `exp(x)` would resolve to `Double.exp(_:)` and
// recurse forever, so libm gets called from out here where no such static
// member is in scope.
//
@inline(__always) private func libm_exp     (_ x: Double) -> Double { return exp(x)   }
@inline(__always) private func libm_expm1   (_ x: Double) -> Double { return expm1(x) }
@inline(__always) private func libm_exp2    (_ x: Double) -> Double { return exp2(x)  }
@inline(__always) private func libm_cosh    (_ x: Double) -> Double { return cosh(x)  }
@inline(__always) private func libm_sinh    (_ x: Double) -> Double { return sinh(x)  }
@inline(__always) private func libm_tanh    (_ x: Double) -> Double { return tanh(x)  }
@inline(__always) private func libm_cos     (_ x: Double) -> Double { return cos(x)   }
@inline(__always) private func libm_sin     (_ x: Double) -> Double { return sin(x)   }
@inline(__always) private func libm_tan     (_ x: Double) -> Double { return tan(x)   }
@inline(__always) private func libm_log     (_ x: Double) -> Double { return log(x)   }
@inline(__always) private func libm_log1p   (_ x: Double) -> Double { return log1p(x) }
@inline(__always) private func libm_log2    (_ x: Double) -> Double { return log2(x)  }
@inline(__always) private func libm_log10   (_ x: Double) -> Double { return log10(x) }
@inline(__always) private func libm_acosh   (_ x: Double) -> Double { return acosh(x) }
@inline(__always) private func libm_asinh   (_ x: Double) -> Double { return asinh(x) }
@inline(__always) private func libm_atanh   (_ x: Double) -> Double { return atanh(x) }
@inline(__always) private func libm_acos    (_ x: Double) -> Double { return acos(x)  }
@inline(__always) private func libm_asin    (_ x: Double) -> Double { return asin(x)  }
@inline(__always) private func libm_atan    (_ x: Double) -> Double { return atan(x)  }
@inline(__always) private func libm_cbrt    (_ x: Double) -> Double { return cbrt(x)  }
@inline(__always) private func libm_erf     (_ x: Double) -> Double { return erf(x)   }
@inline(__always) private func libm_erfc    (_ x: Double) -> Double { return erfc(x)  }
@inline(__always) private func libm_tgamma  (_ x: Double) -> Double { return tgamma(x)}
@inline(__always) private func libm_pow     (_ x: Double, _ y: Double) -> Double { return pow(x, y)   }
@inline(__always) private func libm_atan2   (_ y: Double, _ x: Double) -> Double { return atan2(y, x) }
@inline(__always) private func libm_hypot   (_ x: Double, _ y: Double) -> Double { return hypot(x, y) }
// The Swift overlays reshape `lgamma` into a `(Double, Int)` tuple, so the
// reentrant spelling is the portable way to reach plain log|Γ(x)|.  Deriving it
// as `log(abs(tgamma(x)))` instead loses ~4 ulps near the zeros at -2.457… and
// friends, and overflows for x > 171 where Γ does but log Γ does not.
#if os(Windows)
@inline(__always) private func libm_lgamma(_ x: Double) -> Double { return lgamma(x) }
#else
@inline(__always) private func libm_lgamma(_ x: Double) -> Double {
    var sign: Int32 = 0
    return lgamma_r(x, &sign)
}
#endif

extension Double : Real {
    public static func exp(_ x: Double) -> Double          { return libm_exp(x)    }
    public static func expMinusOne(_ x: Double) -> Double   { return libm_expm1(x)  }
    public static func exp2(_ x: Double) -> Double          { return libm_exp2(x)   }
    public static func cosh(_ x: Double) -> Double          { return libm_cosh(x)   }
    public static func sinh(_ x: Double) -> Double          { return libm_sinh(x)   }
    public static func tanh(_ x: Double) -> Double          { return libm_tanh(x)   }
    public static func cos(_ x: Double) -> Double           { return libm_cos(x)    }
    public static func sin(_ x: Double) -> Double           { return libm_sin(x)    }
    public static func tan(_ x: Double) -> Double           { return libm_tan(x)    }
    public static func log(_ x: Double) -> Double           { return libm_log(x)    }
    public static func log(onePlus x: Double) -> Double     { return libm_log1p(x)  }
    public static func log2(_ x: Double) -> Double          { return libm_log2(x)   }
    public static func log10(_ x: Double) -> Double         { return libm_log10(x)  }
    public static func acosh(_ x: Double) -> Double         { return libm_acosh(x)  }
    public static func asinh(_ x: Double) -> Double         { return libm_asinh(x)  }
    public static func atanh(_ x: Double) -> Double         { return libm_atanh(x)  }
    public static func acos(_ x: Double) -> Double          { return libm_acos(x)   }
    public static func asin(_ x: Double) -> Double          { return libm_asin(x)   }
    public static func atan(_ x: Double) -> Double          { return libm_atan(x)   }
    public static func erf(_ x: Double) -> Double           { return libm_erf(x)    }
    public static func erfc(_ x: Double) -> Double          { return libm_erfc(x)   }
    public static func gamma(_ x: Double) -> Double         { return libm_tgamma(x) }
    public static func pow(_ x: Double, _ y: Double) -> Double  { return libm_pow(x, y)   }
    public static func atan2(y: Double, x: Double) -> Double     { return libm_atan2(y, x) }
    public static func hypot(_ x: Double, _ y: Double) -> Double { return libm_hypot(x, y) }
    /// An integral exponent is exact for negative `x`, where `pow(x, y)` is NaN.
    public static func pow(_ x: Double, _ n: Int) -> Double {
        return libm_pow(x, Double(n))
    }
    public static func root(_ x: Double, _ n: Int) -> Double {
        if x < 0 && n % 2 == 0 { return .nan }
        if n == 3 { return libm_cbrt(x) }
        return Double(signOf: x, magnitudeOf: libm_pow(Swift.abs(x), 1/Double(n)))
    }
    public static func logGamma(_ x: Double) -> Double       { return libm_lgamma(x) }
}

// MARK: - the four that swift-numerics defaults too
//
// `extension Real` above defaults `sqrt`, `exp10`, `reciprocal` and `signGamma`,
// and apple/swift-numerics defaults the same four on *its* `Real`.  A type
// conforming to both then has two equally specific candidates for each -- neither
// protocol refines the other, so nothing breaks the tie -- and a requirement with
// two equally good witnesses is unsatisfied rather than overloaded:
//
//     error: type 'BigFloat' does not conform to protocol 'AlgebraicField'
//     note: multiple matching properties named 'reciprocal' with type 'BigFloat?'
//
// A member declared on the concrete type outranks any protocol-extension default,
// so spelling these out here settles it.  It is a dozen forwarding lines that save
// every consumer of both packages from writing them, and it is the reason
// `extension BigFloat: RealModule.Real {}` can be empty.
//
// Each body reaches a differently-shaped function on purpose.  These *are* the
// witnesses for BigNum's own requirements now, so a body calling the one-argument
// form would call itself.

extension BigFloatOf {
    public static func sqrt(_ x: BigFloatOf) -> BigFloatOf {
        return sqrt(x, precision: Self.precision, debug: false)
    }
    public static func exp10(_ x: BigFloatOf) -> BigFloatOf {
        return pow(10, x, precision: Self.precision, debug: false)
    }
    public static func signGamma(_ x: BigFloatOf) -> FloatingPointSign {
        return _signGamma(x)
    }
    public var reciprocal: BigFloatOf? { return _reciprocal(of: self) }
}

extension BigRat {
    public static func sqrt(_ x: BigRat) -> BigRat {
        return sqrt(x, precision: BigRat.precision, debug: false)
    }
    public static func exp10(_ x: BigRat) -> BigRat {
        return pow(10, x, precision: BigRat.precision, debug: false)
    }
    public static func signGamma(_ x: BigRat) -> FloatingPointSign {
        return _signGamma(x)
    }
    public var reciprocal: BigRat? { return _reciprocal(of: self) }
    /// `BigFloat` declares `/` on the struct, so it already outranks
    /// `AlgebraicField`'s default; a rational's comes from `extension RationalType`
    /// and merely ties with it.
    public static func / (a: BigRat, b: BigRat) -> BigRat { return a.over(b) }
}

extension Double {
    public static func sqrt(_ x: Double) -> Double { return x.squareRoot() }
    // No `exp10` here: swift-numerics declares one *concretely* on `Double`
    // (RealModule/Double+Real.swift), so BigNum's protocol-extension default loses
    // to it and there is no ambiguity.  Declaring ours concretely too would make
    // two equally good candidates and break the call.
    public static func signGamma(_ x: Double) -> FloatingPointSign { return _signGamma(x) }
    public var reciprocal: Double? { return _reciprocal(of: self) }
}

/// The bodies of the two that cannot forward to a differently-shaped twin, kept
/// here so the three types above share one copy.  Both match what `extension Real`
/// does, and that generic version stays for any other conformer.
@inline(__always) internal func _reciprocal<T:Real>(of x: T) -> T? {
    let recip = 1/x
    if recip.isNormal || x.isZero || !x.isFinite { return recip }
    return nil
}
@inline(__always) internal func _signGamma<T:FloatingPoint>(_ x: T) -> FloatingPointSign {
    if x >= 0 { return .plus }
    let trunc = x.rounded(.towardZero)
    if x == trunc { return .plus }              // a pole, not a sign change
    let half = (trunc / 2).rounded(.towardZero)
    return half * 2 == trunc ? .minus : .plus
}
