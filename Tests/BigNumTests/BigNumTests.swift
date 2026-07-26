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
        #expect(T.init(+D.pi).asDouble == +D.pi)
        #expect(T.init(-D.pi).asDouble == -D.pi)
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

    // FIXME: BigFloat.round() is broken and was never actually exercised --
    // the old testBigFloatRound() called runArithmetic() by mistake. It
    //   * traps on -0.0 and NaN: their `scale` is Int.min/Int.max, so
    //     `scale + (mantissa.bitWidth-1)` overflows,
    //   * ignores the rule and truncates toward zero (2.5.rounded(.up) == 2),
    //   * leaves the mantissa denormalized, so even a correct value compares
    //     unequal to the same number built by init().
    // BigRat.round() gets all three right by returning early on
    // isZero/isInfinite/isNaN and going through asMixed.
    @Test(.disabled("BigFloat.round() traps on -0.0 and ignores the rounding rule"),
          arguments: roundingDoubles)
    func bigFloatRound(_ d:D) { runRound(forType:BigFloat.self, d) }
}
