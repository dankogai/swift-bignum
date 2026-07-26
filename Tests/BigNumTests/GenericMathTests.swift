import Testing
import Foundation
@testable import BigNum

/// `GenericMath` against `Double`'s `<math.h>`, one edge-case argument per test.
///
/// `.serialized` is load-bearing, not a style choice. `GenericMath` memoizes
/// √2, e, log 2, log 10 and π/4 in plain `static var`s with no synchronization,
/// and it publishes the new `.precision` *before* it stores the new `.value`.
/// Nested calls raise the working precision as they go (`logGamma` recurses at
/// `px + 32`, `erfc` asks for `getEpsilon(precision: px * 2)`), so the write
/// path is reachable at any precision -- pre-computing the constants up front
/// does not close the window. Run two of these concurrently, as Swift Testing
/// does by default, and they hand each other a half-written NaN.
/// BigNumTests and RationalTests never reach these caches, so they stay parallel.
@Suite(.serialized) struct GenericMathTests {
    typealias D = Double

    /// enough headroom that a 128-bit result is exact to the last bit of a `Double`
    static let px = 128
    /// 709.78...: `Double.exp()` overflows past this, `BigNum` does not
    static let lgfm = D.log(D.greatestFiniteMagnitude)

    // MARK: every unary function, on one argument

    func runUnary<R:BigFloatingPoint>(forType T:R.Type, _ d:D) {
        let px = Self.px, lgfm = Self.lgfm
        let q = T.init(d)
        func check(_ name:String, _ rd:D, _ rq:R,
                   ulp:Int = 1, unless ok:@autoclosure ()->Bool = false) {
            if let why = mismatch(rd, rq, ulp:ulp, unless:ok()) {
                Issue.record("\(R.self).\(name)(\(d.debugDescription)) \(why)")
            }
        }
        var (rd, rq):(D, R)
        // the argument itself must survive the round trip first
        #expect(d.isNaN ? q.isNaN : q.asDouble == d, "\(R.self).init(\(d.debugDescription))")
        // roots
        (rd, rq) = (D.sqrt(d), T.sqrt(q, precision:px))
        check("sqrt", rd, rq)
        // exponentials -- Double overflows well before BigNum does
        (rd, rq) = (D.exp(d), T.exp(q, precision:px))
        check("exp", rd, rq, unless: d == D.log(rq.asDouble) || lgfm < d.magnitude)
        // KNOWN BUG: expMinusOne() sums an alternating series and breaks out on
        // `t < epsilon` with a *signed* t, so for -log 2 < x < 0 it returns after
        // the very first term -- expMinusOne(-0.5) == -0.5, not -0.3934693...
        // (exp() has the same test but is safe: it reflects negatives first.)
        // The old suite could not see this: its error term was
        // `abs(qrd - rq) / rq`, and dividing by the *signed* result made every
        // negative answer compare as within tolerance no matter how wrong.
        (rd, rq) = (D.expMinusOne(d), T.expMinusOne(q, precision:px))
        withKnownIssue("expMinusOne() aborts its series for negative x",
                       isIntermittent: true) {  // exact for arguments near zero
            check("expMinusOne", rd, rq, unless: d == D.log(onePlus:rq.asDouble))
        }
        // logarithms
        (rd, rq) = (D.log(d), T.log(q, precision:px))
        check("log", rd, rq, unless: d == D.exp(rq.asDouble))
        (rd, rq) = (D.log2(d), T.log2(q, precision:px))
        check("log2", rd, rq, unless: d == D.pow(2, rq.asDouble))
        (rd, rq) = (D.log10(d), T.log10(q, precision:px))
        check("log10", rd, rq, unless: d == D.pow(10, rq.asDouble))
        (rd, rq) = (D.log(onePlus:d), T.log1p(q, precision:px))
        check("log1p", rd, rq, unless: d == D.expMinusOne(rq.asDouble))
        // trigonometric
        (rd, rq) = (D.sin(d), T.sin(q, precision:px))
        check("sin", rd, rq, unless: d == D.asin(rq.asDouble))
        (rd, rq) = (D.cos(d), T.cos(q, precision:px))
        check("cos", rd, rq, unless: d == D.acos(rq.asDouble))
        // ulp = 2 needed for macOS (clang?)
        //   BigRational.tan(0.9999980926550052) !~ Double.tan() // err=0x1.2a219d9e9b7f7p-52
        (rd, rq) = (D.tan(d), T.tan(q, precision:px))
        check("tan", rd, rq, ulp:2, unless: d == D.atan(rq.asDouble))
        // inverse trigonometric
        (rd, rq) = (D.asin(d), T.asin(q, precision:px))
        check("asin", rd, rq, unless: d == D.sin(rq.asDouble))
        (rd, rq) = (D.acos(d), T.acos(q, precision:px))
        check("acos", rd, rq, unless: d == D.cos(rq.asDouble))
        (rd, rq) = (D.atan(d), T.atan(q, precision:px))
        check("atan", rd, rq, unless: d == D.tan(rq.asDouble))
        // hyperbolic -- overflows like exp
        (rd, rq) = (D.sinh(d), T.sinh(q, precision:px))
        check("sinh", rd, rq, unless: d == D.asinh(rq.asDouble) || lgfm < d.magnitude)
        (rd, rq) = (D.cosh(d), T.cosh(q, precision:px))
        check("cosh", rd, rq, unless: d == D.acosh(rq.asDouble) || lgfm < d.magnitude)
        // ulp = 2 needed on Linux (glibc?)
        //   BigRational.tanh(0.8888888888888888) !~ Double.tanh() // err=0x1.05db0bfda6e13p-52
        (rd, rq) = (D.tanh(d), T.tanh(q, precision:px))
        check("tanh", rd, rq, ulp:2, unless: d == D.atanh(rq.asDouble))
        // inverse hyperbolic
        (rd, rq) = (D.asinh(d), T.asinh(q, precision:px))
        check("asinh", rd, rq, unless: d == D.sinh(rq.asDouble))
        (rd, rq) = (D.acosh(d), T.acosh(q, precision:px))
        check("acosh", rd, rq, unless: d == D.cosh(rq.asDouble))
        (rd, rq) = (D.atanh(d), T.atanh(q, precision:px))
        check("atanh", rd, rq, unless: d == D.tanh(rq.asDouble))
    }

    // BigRat is left out on purpose: exact rationals blow up on the
    // transcendentals, and BigFloat exercises the same GenericMath code.
    @Test(arguments: edgeDoubles.filter { $0.magnitude != .greatestFiniteMagnitude })
    func unaryBigFloat(_ d:D) { runUnary(forType:BigFloat.self, d) }

    // MARK: atan2 -- all nine sign/zero/infinity quadrant cases

    func runAtan2<R:BigFloatingPoint>(forType T:R.Type, _ y:D) {
        for x in Self.atan2Args {
            #expect(
                T.atan2(y:T.init(y), x:T.init(x), precision:Self.px).asDouble == D.atan2(y:y, x:x),
                "\(R.self).atan2(y:\(y), x:\(x))"
            )
        }
    }
    static let atan2Args:[D] = [-.infinity, -1.0, -0.0, +0.0, +1.0, +.infinity]

    @Test(arguments: atan2Args)
    func atan2BigRat(_ y:D)   { runAtan2(forType:BigRat.self,   y) }
    @Test(arguments: atan2Args)
    func atan2BigFloat(_ y:D) { runAtan2(forType:BigFloat.self, y) }

    // MARK: erf, erfc, gamma and logGamma against Double

    func runErfGamma<R:BigFloatingPoint>(forType T:R.Type, _ d:D) {
        let px = Self.px
        func check(_ name:String, _ rd:D, _ rq:R, ulp:Int) {
            if let why = mismatch(rd, rq, ulp:ulp) {
                Issue.record("\(R.self).\(name)(\(d.debugDescription)) \(why)")
            }
        }
        let q = T.init(d)
        check("erf",   D.erf(d),   T.erf(q,  precision:px), ulp:2)
        check("erfc",  D.erfc(d),  T.erfc(q, precision:px), ulp:2)
        check("gamma", D.gamma(d), T.gamma(q, precision:px), ulp:4)
        // Double.logGamma() itself is off by a few ulps around its zeros
        check("logGamma", D.logGamma(d), T.logGamma(q, precision:px), ulp:8)
    }
    /// the poles at 0 and the negative integers, the half-integers where the
    /// reflection formula kicks in, and the point erfc() switches algorithm
    static let erfGammaArgs:[D] = [
        .nan, -.infinity, +.infinity, -0.0, +0.0,
        -2.5, -1.5, -1.0, 0.5, 1.0, 1.5, 2.0, 6.0, 10.5,
    ]

    @Test(arguments: erfGammaArgs)
    func erfGammaBigRat(_ d:D)   { runErfGamma(forType:BigRat.self,   d) }
    @Test(arguments: erfGammaArgs)
    func erfGammaBigFloat(_ d:D) { runErfGamma(forType:BigFloat.self, d) }

    // MARK: erf, erfc, gamma and logGamma beyond what Double can tell us

    /// the expected values are the leading digits of the exact ones
    func runErfGammaExact<R:BigFloatingPoint>(forType T:R.Type) {
        let px = 256    // 77 decimal digits -- way more than the 40 we check
        func ok(_ name:String, _ rq:R, _ expected:String) {
            let got = rq.toFloatingPointString()
            #expect(got.hasPrefix(expected), "\(R.self).\(name): \(got.prefix(expected.count))")
        }
        ok("erf(1)",        T.erf(T.init(1.0), precision:px),
           "+0.8427007929497148693412206350826092592960")
        ok("erfc(3/2)",     T.erfc(T.init(1.5), precision:px),
           "+0.0338948535246892729330237383540521413185")
        // erfc() switches to the continued fraction around here.
        // erfc(12) == 1.3562611692059042127803061565904...e-64
        ok("erfc(12)",      T.erfc(T.init(12.0), precision:px),
           "+0." + String(repeating:"0", count:63) + "1356261169205904212780306156590")
        ok("erfc(-12)",     T.erfc(T.init(-12.0), precision:px),
           "+1.9999999999999999999999999999999999999999")
        ok("gamma(1/2)",    T.gamma(T.init(0.5), precision:px),
           "+1.7724538509055160272981674833411451827975")
        ok("gamma(-5/2)",   T.gamma(T.init(-2.5), precision:px),
           "-0.9453087204829418812256893244486107641586")
        ok("logGamma(-5/2)", T.logGamma(T.init(-2.5), precision:px),
           "-0.0562437164976740506725945300976542841229")
        ok("logGamma(100)", T.logGamma(T.init(100.0), precision:px),
           "+359.13420536957539877604401046028690961262")
        // Γ(n) == (n-1)!
        #expect(T.gamma(T.init(21.0), precision:px).toFloatingPointString()
                == "+2432902008176640000.0", "\(R.self).gamma(21)")
    }
    @Test func erfGammaExactBigRat()   { runErfGammaExact(forType:BigRat.self) }
    @Test func erfGammaExactBigFloat() { runErfGammaExact(forType:BigFloat.self) }

    // MARK: the two extremes of the exponent range

    /// KNOWN BUG -- this test has to come last, and `.serialized` above is what
    /// guarantees it does. `sin`/`cos`/`tan` of an angle this large make
    /// `normalizeAngle()` ask for π at `128 + 1023` bits, and that poisons the
    /// shared constant cache for good:
    ///
    ///   * `RationalType.truncate(width:)` sizes the denominator with
    ///     `max(den.bitWidth - 1, width)`, so truncating that π/4 back down to
    ///     128 bits keeps its 1153-bit denominator;
    ///   * `BigRat.asDouble` then divides two BigInts that are each far past
    ///     `Double`'s range, so `inf/inf` comes back as NaN.
    ///
    /// From that point on every `BigRat.PI()` at <= 1151 bits reads the cached
    /// value and returns NaN, which takes `atan2`, `erf`, `gamma` and friends
    /// with it. The old suite never noticed because XCTest ran its tests in
    /// alphabetical order, which put `testUnaryBigFloat` last by luck.
    @Test(arguments: [-D.greatestFiniteMagnitude, +D.greatestFiniteMagnitude])
    func unaryBigFloatAtTheExtremes(_ d:D) { runUnary(forType:BigFloat.self, d) }
}
