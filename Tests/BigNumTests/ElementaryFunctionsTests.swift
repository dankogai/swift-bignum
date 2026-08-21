import Testing
@testable import BigNum

///
/// `BigFloatingPoint`'s elementary functions at their edges: NaN, ±0, ±∞, and the
/// one or two arguments where each changes branch or leaves its domain.  Nothing
/// else.
///
/// The expected values are written out rather than taken from the host `libm`.
/// They are a contract -- what these functions *must* return -- so they should
/// not move when someone builds against a different C library, and a reader
/// should be able to check them against C99 Annex F without running anything.
///
/// **Not covered here, on purpose:** accuracy at ordinary arguments.  Nothing in
/// this file would notice `exp` losing its last three bits, `erfc` picking the
/// wrong branch of its continued fraction, or `logGamma` drifting at 256 bits.
/// Those need a value-comparison suite, which this deliberately is not.
///
/// `.serialized` is kept for run-to-run stability of the timings this suite prints,
/// not for correctness.  It used to be load-bearing: the constants were memoised in
/// `static var`s and two tests touching them at once could corrupt the cache.  They
/// are literals now (see Constants.swift), with nothing to share, so
/// `ConcurrencyTests` exercises them from 64 threads on purpose.
@Suite(.serialized) struct ElementaryFunctionsTests {}

private typealias D = Double

/// Enough that every answer below lands on the correctly-rounded `Double`; the
/// edges cost nothing to evaluate, so there is no reason to skimp.
private let px = 64

/// What a function must return.  `.value` compares bit for bit, which is the
/// point: the sign of a zero and the direction of an infinity are contract.
private enum Want : Sendable {
    case nan
    case value(Double)
}

/// One function, in both flavors, with the arguments worth asking it about.
private struct Fn : Sendable, CustomStringConvertible {
    let name:String
    let float:@Sendable (BigFloat) -> BigFloat
    let rat:  @Sendable (BigRat)   -> BigRat
    let edges:[(arg:Double, want:Want)]
    var description:String { return name }

    init(_ name:String,
         _ float:@escaping @Sendable (BigFloat) -> BigFloat,
         _ rat:@escaping @Sendable (BigRat) -> BigRat,
         _ edges:[(arg:Double, want:Want)])
    {
        (self.name, self.float, self.rat, self.edges) = (name, float, rat, edges)
    }
}

private func show(_ d:Double) -> String {
    if d.isNaN      { return "nan" }
    if d.isInfinite { return d < 0 ? "-inf" : "+inf" }
    if d.isZero     { return d.sign == .minus ? "-0" : "+0" }
    return d.debugDescription
}

private let functions:[Fn] = [
    // MARK: roots
    Fn("sqrt", { BigFloat.sqrt($0, precision:px) }, { BigRat.sqrt($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .value(.infinity)),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),      // √-0 keeps its sign
        (1, .value(1)), (-1, .nan),                      // and leaves the domain below 0
    ]),

    // MARK: exponentials.  Double overflows near 709; BigNum never does, so the
    // only edges are the ones at infinity.
    Fn("exp", { BigFloat.exp($0, precision:px) }, { BigRat.exp($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .value(+0.0)), (+.infinity, .value(.infinity)),
        (-0.0, .value(1)), (+0.0, .value(1)),
    ]),
    // NOTE: negative arguments are the interesting ones -- this series alternates,
    // and it once broke out of its loop on a *signed* term comparison, returning
    // after the very first one.
    Fn("expMinusOne", { BigFloat.expMinusOne($0, precision:px) },
                      { BigRat.expMinusOne($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .value(-1)), (+.infinity, .value(.infinity)),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),      // e^x - 1 keeps the sign of x
    ]),

    // MARK: logarithms.  Zero is the pole, one is the zero, and everything
    // negative is off the domain.
    Fn("log", { BigFloat.log($0, precision:px) }, { BigRat.log($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .value(.infinity)),
        (-0.0, .value(-.infinity)), (+0.0, .value(-.infinity)),
        (1, .value(+0.0)), (-1, .nan),
    ]),
    Fn("log2", { BigFloat.log2($0, precision:px) }, { BigRat.log2($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .value(.infinity)),
        (-0.0, .value(-.infinity)), (+0.0, .value(-.infinity)),
        (1, .value(+0.0)), (2, .value(1)), (-1, .nan),
    ]),
    Fn("log10", { BigFloat.log10($0, precision:px) }, { BigRat.log10($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .value(.infinity)),
        (-0.0, .value(-.infinity)), (+0.0, .value(-.infinity)),
        (1, .value(+0.0)), (10, .value(1)), (-1, .nan),
    ]),
    // log1p's pole and domain edge sit at -1, not 0
    Fn("log1p", { BigFloat.log1p($0, precision:px) }, { BigRat.log1p($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .value(.infinity)),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),
        (-1, .value(-.infinity)), (-2, .nan),
    ]),

    // MARK: trigonometric.  There is no answer at infinity, and the angle
    // reduction has to not invent one.
    Fn("sin", { BigFloat.sin($0, precision:px) }, { BigRat.sin($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .nan),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),
    ]),
    Fn("cos", { BigFloat.cos($0, precision:px) }, { BigRat.cos($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .nan),
        (-0.0, .value(1)), (+0.0, .value(1)),
    ]),
    Fn("tan", { BigFloat.tan($0, precision:px) }, { BigRat.tan($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .nan),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),
    ]),
    // sinPi and cosPi answer exactly at every half-integer, which is most of what
    // there is to say about them at their edges.  The zeros are all +0, including
    // `sinPi(-0)` -- where `sin(-0)` is -0.  A zero of sin(πx) is approached from
    // both sides, so its sign is a convention rather than a limit, and this is the
    // convention `sinPi` has always had.
    Fn("sinPi", { BigFloat.sinPi($0, precision:px) }, { BigRat.sinPi($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .nan),
        (-0.0, .value(+0.0)), (+0.0, .value(+0.0)),
        (-1, .value(+0.0)), (1, .value(+0.0)), (2, .value(+0.0)),
        (-0.5, .value(-1)), (0.5, .value(1)), (1.5, .value(-1)),
    ]),
    Fn("cosPi", { BigFloat.cosPi($0, precision:px) }, { BigRat.cosPi($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .nan),
        (-0.0, .value(1)), (+0.0, .value(1)),
        (-1, .value(-1)), (1, .value(-1)), (2, .value(1)),
        (-0.5, .value(+0.0)), (0.5, .value(+0.0)), (1.5, .value(+0.0)),
    ]),

    // MARK: inverse trigonometric.  asin and acos are the two with a bounded
    // domain, so ±1 is both a boundary and an exact answer.
    Fn("asin", { BigFloat.asin($0, precision:px) }, { BigRat.asin($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .nan),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),
        (-1, .value(-D.pi/2)), (1, .value(D.pi/2)),
        (-2, .nan), (2, .nan),
    ]),
    Fn("acos", { BigFloat.acos($0, precision:px) }, { BigRat.acos($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .nan),
        (-0.0, .value(D.pi/2)), (+0.0, .value(D.pi/2)),
        (-1, .value(D.pi)), (1, .value(+0.0)),
        (-2, .nan), (2, .nan),
    ]),
    Fn("atan", { BigFloat.atan($0, precision:px) }, { BigRat.atan($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .value(-D.pi/2)), (+.infinity, .value(D.pi/2)),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),
    ]),

    // MARK: hyperbolic
    Fn("sinh", { BigFloat.sinh($0, precision:px) }, { BigRat.sinh($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .value(-.infinity)), (+.infinity, .value(.infinity)),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),
    ]),
    Fn("cosh", { BigFloat.cosh($0, precision:px) }, { BigRat.cosh($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .value(.infinity)), (+.infinity, .value(.infinity)),
        (-0.0, .value(1)), (+0.0, .value(1)),            // even, so both ends are +∞
    ]),
    Fn("tanh", { BigFloat.tanh($0, precision:px) }, { BigRat.tanh($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .value(-1)), (+.infinity, .value(1)),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),
    ]),

    // MARK: inverse hyperbolic.  acosh starts at 1 and atanh ends at ±1.
    Fn("asinh", { BigFloat.asinh($0, precision:px) }, { BigRat.asinh($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .value(-.infinity)), (+.infinity, .value(.infinity)),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),
    ]),
    Fn("acosh", { BigFloat.acosh($0, precision:px) }, { BigRat.acosh($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .value(.infinity)),
        (-0.0, .nan), (+0.0, .nan),                      // the domain starts at 1
        (1, .value(+0.0)), (0.5, .nan), (-1, .nan),
    ]),
    Fn("atanh", { BigFloat.atanh($0, precision:px) }, { BigRat.atanh($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .nan),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),
        (-1, .value(-.infinity)), (1, .value(.infinity)),  // poles, not domain errors
        (-2, .nan), (2, .nan),
    ]),

    // MARK: error function
    Fn("erf", { BigFloat.erf($0, precision:px) }, { BigRat.erf($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .value(-1)), (+.infinity, .value(1)),
        (-0.0, .value(-0.0)), (+0.0, .value(+0.0)),
    ]),
    Fn("erfc", { BigFloat.erfc($0, precision:px) }, { BigRat.erfc($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .value(2)), (+.infinity, .value(+0.0)),
        (-0.0, .value(1)), (+0.0, .value(1)),
    ]),

    // MARK: gamma.  Γ has a pole at every non-positive integer; the sign of zero
    // decides which way the one at the origin goes.
    Fn("gamma", { BigFloat.gamma($0, precision:px) }, { BigRat.gamma($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .nan), (+.infinity, .value(.infinity)),
        (-0.0, .value(-.infinity)), (+0.0, .value(.infinity)),
        (1, .value(1)), (2, .value(1)),                  // Γ(n) == (n-1)!
        (-1, .nan), (-2, .nan), (-3, .nan),
    ]),
    // log|Γ| turns every one of those poles into +∞, including the ones where Γ
    // itself is NaN rather than infinite
    Fn("logGamma", { BigFloat.logGamma($0, precision:px) },
                   { BigRat.logGamma($0, precision:px) }, [
        (.nan, .nan), (-.infinity, .value(.infinity)), (+.infinity, .value(.infinity)),
        (-0.0, .value(.infinity)), (+0.0, .value(.infinity)),
        (-1, .value(.infinity)), (-2, .value(.infinity)), (-3, .value(.infinity)),
    ]),
]

extension ElementaryFunctionsTests {

    private func check<R:BigFloatingPoint>(
        _ type:String, _ fn:String, _ arg:Double, _ want:Want, _ got:R
    ) {
        let label = "\(type).\(fn)(\(show(arg)))"
        // Ask the arbitrary-precision value itself, not its `Double` shadow: a
        // NaN or an infinity that only shows up after conversion is a different
        // bug, and toDouble() is not what is under test here.
        switch want {
        case .nan:
            #expect(got.isNaN, "\(label) = \(show(got.toDouble())), want nan")
        case .value(let w) where w.isInfinite:
            #expect(got.isInfinite, "\(label) = \(show(got.toDouble())), want \(show(w))")
            #expect(got.sign == w.sign, "\(label) = \(show(got.toDouble())), want \(show(w))")
        case .value(let w) where w.isZero:
            #expect(got.isZero, "\(label) = \(show(got.toDouble())), want \(show(w))")
            #expect(got.sign == w.sign, "\(label) = \(show(got.toDouble())), want \(show(w))")
        case .value(let w):
            #expect(got.toDouble().bitPattern == w.bitPattern,
                    "\(label) = \(show(got.toDouble())), want \(show(w))")
        }
    }

    // MARK: - every function, at its edges

    @Test(arguments: functions)
    fileprivate func edges(_ f:Fn) {
        for (arg, want) in f.edges {
            check("BigFloat", f.name, arg, want, f.float(BigFloat(arg)))
            check("BigRat",   f.name, arg, want, f.rat(BigRat(arg)))
        }
    }

    /// The premise of every expectation above: if `BigRat(-0.0)` did not keep its
    /// sign, `sin(-0) == -0` would prove nothing.
    @Test func edgeArgumentsSurviveConversion() {
        for (arg, _) in functions.flatMap({ $0.edges }) {
            let (f, r) = (BigFloat(arg), BigRat(arg))
            if arg.isNaN {
                #expect(f.isNaN, "BigFloat(nan)")
                #expect(r.isNaN, "BigRat(nan)")
            } else {
                #expect(f.toDouble().bitPattern == arg.bitPattern, "BigFloat(\(show(arg)))")
                #expect(r.toDouble().bitPattern == arg.bitPattern, "BigRat(\(show(arg)))")
            }
        }
    }

    // MARK: - atan2, which is all edge case

    /// Every combination of sign, zero and infinity in both arguments -- the whole
    /// reason `atan2` exists rather than `atan(y/x)`.  ±∞/±∞ is the cell that
    /// would come out NaN if the quotient really were taken first, and the four
    /// signed-zero rows are the ones that decide between 0 and ±π.
    ///
    /// The grid is C99 Annex F.9.1.4, written out rather than compared against
    /// the host `atan2` -- which is also what makes the one cell below visible.
    @Test func atan2Quadrants() {
        let P = D.pi
        let ys:[D] = [+.infinity, +1.0, +0.0, -0.0, -1.0, -.infinity]
        let xs:[D] = [-.infinity, -1.0, -0.0, +0.0, +1.0, +.infinity]
        let table:[[D]] = [
            //  x: -inf     -1        -0      +0      +1      +inf
            [   3*P/4,    P/2,     P/2,    P/2,    P/2,    P/4  ],   // y: +inf
            [   P,        3*P/4,   P/2,    P/2,    P/4,   +0.0  ],   // y: +1
            [   P,        P,       P,     +0.0,   +0.0,   +0.0  ],   // y: +0
            [  -P,       -P,      -P,     -0.0,   -0.0,   -0.0  ],   // y: -0
            [  -P,       -3*P/4,  -P/2,   -P/2,   -P/4,   -0.0  ],   // y: -1
            [  -3*P/4,   -P/2,    -P/2,   -P/2,   -P/2,   -P/4  ],   // y: -inf
        ]
        func expectCell(_ y:D, _ x:D, _ want:D) {
            let f = BigFloat.atan2(y:BigFloat(y), x:BigFloat(x), precision:px)
            let r = BigRat.atan2(y:BigRat(y), x:BigRat(x), precision:px)
            #expect(f.toDouble().bitPattern == want.bitPattern,
                    "BigFloat.atan2(y:\(show(y)), x:\(show(x))) = \(show(f.toDouble())), want \(show(want))")
            #expect(r.toDouble().bitPattern == want.bitPattern,
                    "BigRat.atan2(y:\(show(y)), x:\(show(x))) = \(show(r.toDouble())), want \(show(want))")
        }
        for (i, y) in ys.enumerated() {
            for (j, x) in xs.enumerated() {
                // atan2(-0, x) for a finite x > 0 comes back +0 instead of -0.
                // `atan2` reaches it through y/x, and `RationalType.init(_:_:)`
                // moves the sign onto the numerator -- where, for a zero, it
                // vanishes: (0, -1) normalizes to (0, +1).  The neighbouring
                // cells survive because they never divide: x == +0 takes the
                // `x.isZero` branch and x == +inf is short-circuited by
                // `over(_:)` returning `negativeZero` outright.
                if y.isZero && y.sign == .minus && x.isFinite && 0 < x {
                    withKnownIssue("atan2(-0, x) loses the sign of zero for finite x > 0") {
                        expectCell(y, x, table[i][j])
                    }
                } else {
                    expectCell(y, x, table[i][j])
                }
            }
        }
    }

    // MARK: - the one edge that is not exact

    /// Γ(1) and Γ(2) are both 1, so log Γ is exactly 0 at both -- and Spouge's
    /// approximation cannot land on 0 exactly.  It gets to within 2^-180 at
    /// `precision: 64`, so this asks only that it be inside the precision it was
    /// given, which still catches a wrong branch or a lost sign.
    @Test func logGammaIsNearlyZeroAtItsZeros() {
        for x in [1.0, 2.0] {
            let f = BigFloat.logGamma(BigFloat(x), precision:px)
            let r = BigRat.logGamma(BigRat(x), precision:px)
            #expect(Swift.abs(f) < BigFloat.getEpsilon(precision:px),
                    "BigFloat.logGamma(\(x)) = \(f.toDouble()), want ~0")
            #expect(Swift.abs(r) < BigRat.getEpsilon(precision:px),
                    "BigRat.logGamma(\(x)) = \(r.toDouble()), want ~0")
        }
    }

    // MARK: - sin(πx) and cos(πx)

    /// What `sinPi`/`cosPi` are *for*.  `sin(PI(precision:px) * x)` rounds π
    /// before it multiplies, so the argument arrives carrying an absolute error of
    /// about `x` ulps of π -- and where the answer is near a zero, that absolute
    /// error is the whole answer.  `sincosPi` reduces `x` exactly and only rounds
    /// the last small product, so its error stays relative.
    ///
    /// The reference here is closed-form rather than another run of the code under
    /// test.  Both of the arguments below sit `e` past a zero of the function
    /// asked about, and both answers are the same -sin(πe) -- which is -πe to
    /// within (πe)³/6, 2^-197 for this `e` and so exact as far as `px` can see:
    ///
    ///     cos(π(½+e)) = -sin(πe)      sin(π(1+e)) = -sin(πe)
    ///
    /// One lands where the ¼ fold and the ½ swap put it, the other where the
    /// `1-a` fold does, so between them every branch of the reduction is on the
    /// hook for its near-zero argument.
    ///
    /// The last expectation is the one that would notice `sincosPi` quietly
    /// turning back into the product: it insists the naive route really is worse
    /// than `px` bits here, so this test cannot pass by both sides being good.
    ///
    /// `limit` is `px + 24` bits rather than `px`.  A result asked for at
    /// `precision: -px` is truncated to `px` bits, and rounding those correctly
    /// takes an intermediate that is better than `px` -- which is what the 32
    /// guard bits inside `sincosPi` are for.  Measured margin is 96 bits at
    /// `px == 64`, and 65 with the guard bits taken out, so this notices if they
    /// go.
    @Test func sincosPiKeepsTheBitsTheNaiveProductLoses() {
        let e     = BigRat(BigInt(1), BigInt(1) << 100)
        let want  = -BigRat.PI(precision:px + 200) * e
        let limit = BigRat.getEpsilon(precision:px + 24)
        func relativeError(_ got:BigRat)->BigRat {
            return ((got - want).divided(by:want, precision:px + 200)).magnitude
        }
        let atHalf  = BigRat.cosPi(BigRat(1,2) + e, precision:px)
        let atWhole = BigRat.sinPi(1 + e, precision:px)
        #expect(relativeError(atHalf) < limit,
                "cosPi(½+2^-100) is off by \(relativeError(atHalf).toDouble()), want < 2^-\(px+24)")
        #expect(relativeError(atWhole) < limit,
                "sinPi(1+2^-100) is off by \(relativeError(atWhole).toDouble()), want < 2^-\(px+24)")
        // BigFloat takes the same path and should reach the same place
        let f = BigFloat.cosPi(BigFloat(1)/2 + BigFloat(BigRat(e)), precision:px)
        #expect(relativeError(BigRat(f)) < limit,
                "BigFloat.cosPi(½+2^-100) is off by more than 2^-\(px+24)")
        let naive = BigRat.cos(BigRat.PI(precision:px) * (BigRat(1,2) + e), precision:px)
        #expect(limit < relativeError(naive),
                "cos(π*(½+2^-100)) is off by only \(relativeError(naive).toDouble()) -- if the product is that accurate the two routes no longer differ and this test is moot")
    }

    /// The identities that hold for every argument, at arguments chosen to land in
    /// each of the four octants the reduction folds and on both sides of an
    /// integer.  `sin² + cos² == 1` is the one that catches a swapped pair or a
    /// sign applied to the wrong half.
    @Test func sincosPiSatisfiesItsIdentities() {
        let limit = BigRat.getEpsilon(precision:px)
        for (n, d) in [(1,3), (1,4), (1,6), (2,3), (3,4), (5,6), (7,8), (-1,3), (-9,7), (13,5)] {
            let x = BigRat(n, d)
            let (s, c) = BigRat.sincosPi(x, precision:px)
            #expect(Swift.abs(s*s + c*c - 1) < limit, "sin²+cos² at \(n)/\(d)")
            #expect(s == BigRat.sinPi(x, precision:px), "sinPi disagrees with sincosPi at \(n)/\(d)")
            #expect(c == BigRat.cosPi(x, precision:px), "cosPi disagrees with sincosPi at \(n)/\(d)")
            // period 2, and a half-period that negates both
            let (s2, c2) = BigRat.sincosPi(x + 2, precision:px)
            #expect(s == s2 && c == c2, "not periodic in 2 at \(n)/\(d)")
            let (s1, c1) = BigRat.sincosPi(x + 1, precision:px)
            #expect(Swift.abs(s + s1) < limit && Swift.abs(c + c1) < limit,
                    "x+1 does not negate at \(n)/\(d)")
            // odd and even
            let (sm, cm) = BigRat.sincosPi(-x, precision:px)
            #expect(s == -sm && c == cm, "not odd/even at \(n)/\(d)")
        }
        // the two arguments whose answers are exact reals
        #expect(Swift.abs(BigRat.sinPi(BigRat(1,6), precision:px) - BigRat(1,2)) < limit,
                "sin(π/6) == ½")
        #expect(Swift.abs(BigRat.cosPi(BigRat(1,3), precision:px) - BigRat(1,2)) < limit,
                "cos(π/3) == ½")
    }

    // MARK: - sincos's argument reduction

    /// `sincos` folds its argument by multiples of π/2, and this is the argument
    /// that punishes a careless fold: π/2 itself, rounded to 1024 bits.  Its
    /// cosine is the 2^-1025-sized morsel that survives the subtraction
    /// `x - 1*(π/2)`, and finding it takes a π/2 wider than the one the answer
    /// was asked in -- the reduction has to notice the cancellation and go back
    /// for more bits.  The previous `sincos` had no such loop and returned pure
    /// noise here (its error was ~2^-131, its answer ~2^-1025); this asks for
    /// the answer good to the working precision, cancellation notwithstanding.
    ///
    /// The reference is closed-form: cos(x) = sin(π/2 - x) and π/2 - x is tiny,
    /// so a 4096-bit π/2 minus `x` *is* the answer, to (π/2-x)³/6 ~ 2^-3000.
    @Test func sincosSurvivesAnArgumentNearAMultipleOfHalfPi() {
        let limit = BigRat.getEpsilon(precision:px + 16)
        do {    // π/2 to 1024 bits: 1025 bits of cancellation
            let x    = BigRat.PI(precision:1024).divided(by:BigRat(2), precision:1024)
            let want = BigRat.PI(precision:4096).divided(by:BigRat(2), precision:4096) - x
            let got  = BigRat.sincos(x, precision:px).cos
            #expect(((got - want)/want).magnitude < limit,
                    "cos(π/2 rounded to 1024 bits): got \(got.toDouble()), want \(want.toDouble())")
        }
        do {    // 3·(π/2) to 200 bits: cancellation *and* k % 4 == 3
            let x    = BigRat.PI(precision:200).divided(by:BigRat(2), precision:200) * 3
            let want = BigRat.PI(precision:4096).divided(by:BigRat(2), precision:4096) * 3 - x
            let got  = BigRat.sincos(x, precision:px).cos
            // cos(3π/2 + d) = +sin(d) = d, and x = 3π/2 - want
            #expect(((got + want)/want).magnitude < limit,
                    "cos(3π/2 rounded to 200 bits): got \(got.toDouble()), want \((-want).toDouble())")
        }
    }

    /// The addition theorem, across arguments that reduce with *different* k --
    /// which is what makes it a test of the reduction and not just of the series:
    /// a wrong quadrant or a sloppy `r` on any one of `a`, `b`, `a+b` breaks the
    /// identity, since the three are folded independently.
    ///
    ///     sin(a+b) = sin a cos b + cos a sin b
    ///     cos(a+b) = cos a cos b - sin a sin b
    ///
    /// The pairs put `a+b` in all four quadrants and across ±: k spans -66 to 65.
    @Test func sincosSatisfiesTheAdditionTheorem() {
        let limit = BigRat.getEpsilon(precision:px)
        let pairs:[(BigRat, BigRat)] = [
            (BigRat(1,3),   BigRat(1)),     // stays in the first fold
            (BigRat(1),     BigRat(1)),     // crosses π/2
            (BigRat(3),     BigRat(1,2)),   // crosses π
            (BigRat(4),     BigRat(1)),     // crosses 3π/2
            (BigRat(-3),    BigRat(-2)),    // negative k
            (BigRat(-3),    BigRat(4)),     // negative *and* positive k in one
                                            // identity -- a quadrant map that is
                                            // wrong only for negative k passes
                                            // the all-negative pair above (the
                                            // errors add consistently) but not
                                            // this one
            (BigRat(100),   BigRat(1,7)),   // k = 63 -- an argument the old code
                                            // wrapped through normalizeAngle
            (BigRat(-100),  BigRat(-3,7)),  // and its negative
        ]
        for (a, b) in pairs {
            let (sa, ca) = BigRat.sincos(a, precision:px)
            let (sb, cb) = BigRat.sincos(b, precision:px)
            let (s, c)   = BigRat.sincos(a + b, precision:px)
            #expect((s - (sa*cb + ca*sb)).magnitude < limit, "sin(\(a.toDouble()) + \(b.toDouble()))")
            #expect((c - (ca*cb - sa*sb)).magnitude < limit, "cos(\(a.toDouble()) + \(b.toDouble()))")
            // and the pair really is a point on the unit circle
            #expect((s*s + c*c - 1).magnitude < limit, "sin²+cos² at \((a+b).toDouble())")
        }
    }

    /// The hyperbolic pair.  `cosh² - sinh² = 1` catches a lost bit on the series
    /// side but is *exact by construction* on the `exp` side (`em` is a true
    /// reciprocal there, and the identity reduces to `ep·em == 1`), so each value
    /// is also held against a 200-bits-wider run of itself -- that comparison
    /// sees both paths, and it is what noticed the pair summing its series at the
    /// target precision and coming back a few bits short.  Limit `px + 8`: with
    /// its guard bits `sinhcosh` agrees with its wider self to ~2^-30 ulp;
    /// without them it misses by up to 6 ulp.
    @Test func sinhcoshSatisfiesItsIdentities() {
        let limit = BigRat.getEpsilon(precision:px + 8)
        for x in [BigRat(1,10), BigRat(9,10), BigRat(1), BigRat(11,10), BigRat(5)] {
            let (s, c) = BigRat.sinhcosh(x, precision:px)
            #expect((c*c - s*s - 1).magnitude < limit, "cosh²-sinh² at \(x.toDouble())")
            let (S, C) = BigRat.sinhcosh(x, precision:px + 200)
            #expect(((s - S)/S).magnitude < limit, "sinh at \(x.toDouble()) vs its wider self")
            #expect(((c - C)/C).magnitude < limit, "cosh at \(x.toDouble()) vs its wider self")
        }
    }

    /// `atan`, against a 200-bits-wider run of itself, on both sides of its folds
    /// at ½ and 1.  The old `atan` subtracted its folds from a target-precision
    /// ATAN1 and came back a few bits short, which `asin` and `acos` then
    /// inherited.
    ///
    /// Asked with a *negative* precision -- `atan`'s convention for "skip the
    /// final rounding" -- because the rounded value can be half an ulp from the
    /// truth with the guard bits or without them; it is the raw value that shows
    /// whether they are there.
    @Test func atanAgreesWithItsWiderSelf() {
        let limit = BigRat.getEpsilon(precision:px + 16)
        for x in [BigRat(1,10), BigRat(2,5), BigRat(3,5), BigRat(9,10), BigRat(2), BigRat(100)] {
            let a = BigRat.atan(x, precision: -px)
            let A = BigRat.atan(x, precision: px + 200)
            #expect(((a - A)/A).magnitude < limit,
                    "atan(\(x.toDouble())) = \(a.toDouble()), want \(A.toDouble())")
        }
    }

    /// "Stays accurate even when |x| is large" is stronger than accurate: the
    /// split is exact, so a huge even integer added to the argument does not
    /// perturb the answer at all -- it produces the identical value, not a nearby
    /// one.  Feeding the same `x` to `sin` through a product cannot do this; at
    /// 2^80 there is no π wide enough for it to matter.
    @Test func sincosPiIsUnmovedByAHugeWholeNumber() {
        let x    = BigRat(1,3)
        let huge = x + BigRat(BigInt(1) << 80)      // even, so nothing even flips sign
        let (s,  c ) = BigRat.sincosPi(x,    precision:px)
        let (sh, ch) = BigRat.sincosPi(huge, precision:px)
        #expect(s == sh && c == ch, "2^80 + 1/3 answers differently from 1/3")
        // and the odd one flips both, exactly
        let (so, co) = BigRat.sincosPi(x + BigRat((BigInt(1) << 80) + 1), precision:px)
        #expect(s == -so && c == -co, "2^80 + 1 + 1/3 is not the negation of 1/3")
    }
}
