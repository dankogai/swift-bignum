import Testing
@testable import BigNum

/// `BigRat` and `BigFloat` as `FloatingPoint`s -- comparison, arithmetic, rounding.
@Suite struct BigNumTests {
    typealias D = Double

    // MARK: comparison

    func runComp<Q:FloatingPoint & DoubleConvertible>(forType T:Q.Type, _ x:D, _ y:D) {
        #expect((T.init(x) == T.init(y)) == (x == y), "\(x) == \(y)")
        #expect((T.init(x) <= T.init(y)) == (x <= y), "\(x) <= \(y)")
        #expect((T.init(x) <  T.init(y)) == (x <  y), "\(x) <  \(y)")
        #expect((T.init(x) >= T.init(y)) == (x >= y), "\(x) >= \(y)")
        #expect((T.init(x) >  T.init(y)) == (x >  y), "\(x) >  \(y)")
        #expect(
            Q(x).isTotallyOrdered(belowOrEqualTo:Q(y)) == x.isTotallyOrdered(belowOrEqualTo:y),
            "\(x).isTotallyOrdered(belowOrEqualTo:\(y))"
        )
    }
    static let comparands:[D] = [-.infinity, -1.5, -0.0, +0.0, 0.5, 1.0, +.infinity]

    @Test(arguments: comparands)
    func bigRatComp(_ x:D)   { for y in Self.comparands { runComp(forType:BigRat.self,   x, y) } }
    @Test(arguments: comparands)
    func bigFloatComp(_ x:D) { for y in Self.comparands { runComp(forType:BigFloat.self, x, y) } }

    // MARK: arithmetic

    func runArithmetic<Q:FloatingPoint & DoubleConvertible>(forType T:Q.Type) {
        #expect(T.init(3) + T.init(2) == T.init(5))
        #expect(T.init(3) - T.init(2) == T.init(1))
        #expect(T.init(3) * T.init(2) == T.init(6))
        #expect(T.init(3) / T.init(2) == T.init(1.5))
        // the Double round trip must be exact both ways
        #expect(T.init(+D.pi).toDouble() == +D.pi)
        #expect(T.init(-D.pi).toDouble() == -D.pi)
    }
    @Test func bigRatArithmetic()   { runArithmetic(forType:BigRat.self) }
    @Test func bigFloatArithmetic() { runArithmetic(forType:BigFloat.self) }

    // MARK: rounding

    func runRound<Q:FloatingPoint & DoubleConvertible>(forType T:Q.Type, _ d:D) {
        let q = Q(d)
        for rule in allRoundingRules {
            #expect(q.rounded(rule) == Q(d.rounded(rule)), "\((d, rule))")
        }
    }
    @Test(arguments: roundingDoubles)
    func bigRatRound(_ d:D)   { runRound(forType:BigRat.self,   d) }

    // NOTE: this never actually ran before -- the old testBigFloatRound() called
    // runArithmetic() by copy-paste, which is how BigFloat.round() came to trap
    // on -0.0, ignore the rule and denormalize its mantissa unnoticed.
    @Test(arguments: roundingDoubles)
    func bigFloatRound(_ d:D) { runRound(forType:BigFloat.self, d) }
}

///
/// `toString(_:radix:)`, which is the only way these three renderings are
/// reachable and was not covered before the formats were merged into it.
/// Both `debugDescription`s are defined in terms of it, so they are pinned here
/// too -- they are what a debugger shows, and silently changing that is the kind
/// of regression nothing else would catch.
///
@Suite struct StringFormatTests {
    /// √2 to 64 bits: a value with a long hex expansion and a power-of-two
    /// denominator, so every format has something to show.
    let root2 = BigRat.sqrt(2, precision:64)

    @Test func pointFormatIsTheDefault() {
        #expect(root2.toString() == "+1.41421356237309504876")
        #expect(root2.toString(.point) == root2.toString())
        #expect(root2.toString(.point, radix:16) == "+1.6a09e667f3bcc908")
        // BigFloat renders through BigRat, so the two agree exactly
        #expect(BigFloat(root2).toString() == root2.toString())
        #expect(BigFloat(root2).description == "1.41421356237309504876")  // no leading +
    }

    @Test func fractionFormatShowsTheRatio() {
        #expect(root2.toString(.fraction)
                  == "(+3260954456333195553/2305843009213693952)")
        // a non-decimal radix announces itself, which is what makes this format
        // and BigRat's debugDescription the same string
        #expect(root2.toString(.fraction, radix:16)
                  == "(+0x2d413cccfe779921/0x2000000000000000)")
        #expect(root2.debugDescription == root2.toString(.fraction, radix:16))
        #expect(BigRat(22).over(BigRat(7)).toString(.fraction) == "(+22/7)")
        #expect(BigRat(-3).over(BigRat(4)).toString(.fraction, radix:16) == "(-0x3/0x4)")
    }

    @Test func exponentFormatIsWhatBigFloatDebugsAs() {
        #expect(root2.toString(.exponent) == "+0x1.6a09e667f3bcc908p0")
        #expect(BigFloat(root2).debugDescription == "+0x1.6a09e667f3bcc908p0")
        #expect(BigFloat(root2).toString(.exponent) == root2.toString(.exponent))
        // hexadecimal by definition: the p counts bits, so radix is ignored
        #expect(root2.toString(.exponent, radix:10) == root2.toString(.exponent))
        #expect(BigRat(1).over(BigRat(2)).toString(.exponent) == "+0x0.8p0")
        #expect(BigRat(-3).over(BigRat(4)).toString(.exponent) == "-0x0.cp0")
    }

    /// The specials have no digits to render, and `.fraction` is the only format
    /// that can still tell a negative zero from a positive one.
    @Test func specialValues() {
        let cases:[(BigRat, point:String, fraction:String, exponent:String)] = [
            (.nan,                "nan",       "(+0/0)",  "nan"),
            (.infinity,           "+infinity", "(+1/0)",  "+infinity"),
            (-BigRat.infinity,    "-infinity", "(-1/0)",  "-infinity"),
            (.zero,               "+0.0",      "(+0/1)",  "+0.0p0"),
            (-BigRat.zero,        "-0.0",      "(+0/-1)", "-0.0p0"),
        ]
        for (q, point, fraction, exponent) in cases {
            #expect(q.toString(.point)    == point,    "point of \(fraction)")
            #expect(q.toString(.fraction) == fraction, "fraction of \(fraction)")
            #expect(q.toString(.exponent) == exponent, "exponent of \(fraction)")
            // a bare radix marker would be noise on a value with no digits
            #expect(q.toString(.fraction, radix:16) == fraction, "hex fraction of \(fraction)")
            let bf = BigFloat(q)
            #expect(bf.toString(.point)    == point,    "BigFloat point of \(fraction)")
            #expect(bf.debugDescription    == exponent, "BigFloat debug of \(fraction)")
        }
    }

    /// The fixed-width rationals and `String.init` route to the same place.
    @Test func fixedWidthAndStringInitAgree() {
        let ir = BigRat(22).over(BigRat(7)).toIntRat()
        #expect(ir.toString() == ir.toBigRat().toString())
        #expect(ir.debugDescription == ir.toBigRat().debugDescription)
        #expect(String(BigFloat(root2), radix:16) == root2.toString(.point, radix:16))
        #expect(String(BigFloat(root2), radix:16, uppercase:true)
                  == root2.toString(.point, radix:16).uppercased())
    }

    ///
    /// `BigFloat(_:radix:)` is failable, so malformed text must come back `nil`.
    /// It used to trap instead: `chars[0]` after a `removeFirst()` on "+" or
    /// "00", and force-unwrapped exponents on "1e", "0x1pz" -- or on any word
    /// with an "e" in it, which made `BigFloat("nonsense")` a crash.
    ///
    @Test func bigFloatStringParsing() {
        let accepted:[(String, Double)] = [
            ("0", 0), ("00", 0), ("000", 0), ("1", 1), ("+2", 2),
            ("1.5", 1.5), ("-1.5", -1.5), ("3.14159", 3.14159),
            ("0x1.8p1", 3), ("0x1p-4", 0.0625), ("-0x1p-4", -0.0625),
            ("0b1011", 11), ("0o17", 15), ("0xff", 255),
            ("1.5e10", 1.5e10),
        ]
        for (text, want) in accepted {
            guard let got = BigFloat(text) else {
                Issue.record("BigFloat(\"\(text)\") was nil, want \(want)") ; continue
            }
            #expect(got.toDouble() == want, "BigFloat(\"\(text)\") == \(got.toDouble())")
        }
        // the sign of a zero survives, which the early return used to drop
        #expect(BigFloat("-0")!.sign == .minus)
        #expect(BigFloat("0")!.sign == .plus)
        #expect(BigFloat("-0")!.isZero)
        // the radix argument stands in for a missing prefix
        #expect(BigFloat("1.8p1", radix:16)!.toDouble() == 3)
        #expect(BigFloat("ff", radix:16)!.toDouble() == 255)

        for text in ["", "+", "-", "--1", "+-1", "nonsense", "1e", "1e+",
                     "0x1p", "0x1pz", "1.2.3", "0x", "0b", "abc", "1z"] {
            #expect(BigFloat(text) == nil, "BigFloat(\"\(text)\") should be nil")
        }
    }
}
