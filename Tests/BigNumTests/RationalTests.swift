import Testing
@testable import BigNum

/// What is specific to `RationalType`: reduction, and the ±0/±inf/NaN algebra
/// that a rational has to synthesize by hand instead of inheriting from IEEE754.
@Suite struct RationalTests {

    // MARK: reduction and arithmetic

    func runBasic<Q:RationalType>(forType T:Q.Type) {
        // constructed fractions are reduced, signs normalized onto the numerator
        #expect(T.init(+2, +4) == T.init(+1, +2))
        #expect(T.init(-2, +4) == T.init(-1, +2))
        #expect(T.init(+2, -4) == T.init(-1, +2))
        #expect(T.init(-2, -4) == T.init(+1, +2))
        #expect(T.init(1, 2) + T.init(1, 3) == T.init(5, 6))
        #expect(T.init(1, 2) - T.init(1, 3) == T.init(1, 6))
        #expect(T.init(1, 2) * T.init(1, 3) == T.init(1, 6))
        #expect(T.init(1, 2) / T.init(1, 3) == T.init(3, 2))
        #expect(T.init(+Double.pi).toDouble() == +Double.pi)
        #expect(T.init(-Double.pi).toDouble() == -Double.pi)
    }
    @Test func bigRatBasic() { runBasic(forType:BigRat.self) }
    @Test func intRatBasic() { runBasic(forType:IntRat.self) }

    // MARK: NaN

    func runNaN<Q:RationalType>(forType T:Q.Type) {
        let n = T.nan
        let o = T.init(1)
        #expect(n.isNaN)
        #expect(!n.isZero)
        #expect(!n.isInfinite)
        #expect(!n.isFinite)
        // NaN compares false against everything, itself included
        #expect(!(n == n))
        #expect(!(n <  0))
        #expect(!(n <= 0))
        #expect(!(n >= 0))
        #expect(!(n >  0))
        // and it propagates
        #expect((n + o).isNaN)
        #expect((n - o).isNaN)
        #expect((n * o).isNaN)
        #expect((n / o).isNaN)
        #expect(n.squareRoot().isNaN)
    }
    @Test func bigRatNaN() {
        runNaN(forType:BigRat.self)
        #expect(BigRat.exp(BigRat.nan).isNaN)
    }
    @Test func intRatNaN() { runNaN(forType:IntRat.self) }

    // MARK: signed zero and infinity

    func runInf<Q:RationalType>(forType T:Q.Type) {
        let zero = T.init(0)
        let one  = T.init(1)
        let two  = one + one
        let half = one.over(two)
        let inf  = one.over(zero)
        // ±0 compare equal but stay distinguishable
        #expect(inf.isInfinite)
        #expect(+zero == -zero)
        #expect((+zero).sign == .plus)
        #expect((-zero).sign == .minus)
        #expect(!(+zero).isIdentical(to: -zero))
        #expect((+one/zero).isIdentical(to: +inf))
        #expect((-one/zero).isIdentical(to: -inf))
        // 0 * inf is the indeterminate form, either way round
        #expect((+zero * +inf).isNaN)
        #expect((-zero * -inf).isNaN)
        #expect((+inf * +zero).isNaN)
        #expect((-inf * -zero).isNaN)
        // 0 / inf keeps the sign
        #expect((+zero / +inf).isIdentical(to: +zero))
        #expect((-zero / +inf).isIdentical(to: -zero))
        #expect((+zero / -inf).isIdentical(to: -zero))
        #expect((-zero / -inf).isIdentical(to: +zero))
        // inf / 0 likewise
        #expect(+inf / +zero == +inf)
        #expect(-inf / +zero == -inf)
        #expect(+inf / -zero == -inf)
        #expect(-inf / -zero == +inf)
        // finite operands: below 1, at 1, above 1
        for q in [half, one, two] {
            #expect(+q * +inf == +inf)
            #expect(-q * +inf == -inf)
            #expect(+inf * -q == -inf)
            #expect(-inf * -q == +inf)
            #expect((+q / +inf).isIdentical(to: +zero))
            #expect((-q / +inf).isIdentical(to: -zero))
            #expect((+q / -inf).isIdentical(to: -zero))
            #expect((-q / -inf).isIdentical(to: +zero))
            // NOTE: adding across signs is NaN here, not the IEEE754 ±inf --
            // Self.+ only keeps the infinity when the signs agree
            #expect(+q + +inf == +inf)
            #expect(-q + -inf == -inf)
            #expect((-q + +inf).isNaN)
            #expect((+q + -inf).isNaN)
            #expect(+inf + +q == +inf)
            #expect(-inf + -q == -inf)
            #expect((+inf + -q).isNaN)
            #expect((-inf + +q).isNaN)
        }
        // inf - inf is the other indeterminate form
        #expect((+inf + -inf).isNaN)
        #expect((-inf + +inf).isNaN)
    }
    @Test func bigRatInf() { runInf(forType:BigRat.self) }
    @Test func intRatInf() { runInf(forType:IntRat.self) }

    // MARK: rounding

    func runRound<Q:RationalType>(forType T:Q.Type, _ d:Double) {
        let q = Q(d)
        for rule in allRoundingRules {
            #expect(q.rounded(rule) == Q(d.rounded(rule)), "\((d, rule))")
        }
    }
    @Test(arguments: roundingDoubles)
    func bigRatRound(_ d:Double) { runRound(forType:BigRat.self, d) }
    @Test(arguments: roundingDoubles)
    func intRatRound(_ d:Double) { runRound(forType:IntRat.self, d) }

    // MARK: comparison

    func runComp<Q:RationalType>(forType T:Q.Type, _ x:Double, _ y:Double) {
        #expect((Q(x) == Q(y)) == (x == y), "\(x) == \(y)")
        #expect((Q(x) <= Q(y)) == (x <= y), "\(x) <= \(y)")
        #expect((Q(x) <  Q(y)) == (x <  y), "\(x) <  \(y)")
        #expect((Q(x) >= Q(y)) == (x >= y), "\(x) >= \(y)")
        #expect((Q(x) >  Q(y)) == (x >  y), "\(x) >  \(y)")
        #expect(
            Q(x).isTotallyOrdered(belowOrEqualTo:Q(y)) == x.isTotallyOrdered(belowOrEqualTo:y),
            "\(x).isTotallyOrdered(belowOrEqualTo:\(y))"
        )
    }
    static let comparands:[Double] = [-.infinity, -1.5, -0.0, +0.0, 0.5, 1.0, +.infinity]

    @Test(arguments: comparands)
    func bigRatComp(_ x:Double) { for y in Self.comparands { runComp(forType:BigRat.self, x, y) } }
    @Test(arguments: comparands)
    func intRatComp(_ x:Double) { for y in Self.comparands { runComp(forType:IntRat.self, x, y) } }
}
