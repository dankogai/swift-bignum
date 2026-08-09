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
/// `.serialized` is load-bearing, not a style choice.  ElementaryFunctions.swift
/// memoizes √2, e, log 2, log 10 and π/4 in plain `static var`s, and `asin`,
/// `acos`, `log2`, `log10` and `atan2` all reach them.  Value and precision go
/// into one assignment, so a reader cannot pick up a NaN a writer has not filled
/// in yet, but an `Int` beside a BigInt-backed struct still is not written
/// atomically and two threads can tear one.
///
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
}
