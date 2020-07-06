import XCTest
@testable import BigNum

final class RationalTests: XCTestCase {
    //
    func runBasic<Q:RationalType>(forType T:Q.Type) {
        XCTAssertEqual(T.init(+2, +4), T.init(+1, +2))
        XCTAssertEqual(T.init(-2, +4), T.init(-1, +2))
        XCTAssertEqual(T.init(-2, +4), T.init(-1, +2))
        XCTAssertEqual(T.init(-2, -4), T.init(+1, +2))
        XCTAssertEqual( T.init(1,2) + T.init(1, 3), T.init(5, 6))
        XCTAssertEqual( T.init(1,2) - T.init(1, 3), T.init(1, 6))
        XCTAssertEqual( T.init(1,2) * T.init(1, 3), T.init(1, 6))
        XCTAssertEqual( T.init(1,2) / T.init(1, 3), T.init(3, 2))
        XCTAssertEqual( T.init(+Double.pi).asDouble, +Double.pi)
        XCTAssertEqual( T.init(-Double.pi).asDouble, -Double.pi)
    }
    func testBigRatBasic() { runBasic(forType: BigRat.self) }
    func testIntRatBasic()  { runBasic(forType: IntRat.self) }
    //
    func runNaN<Q:RationalType>(forType T:Q.Type) {
        let nan = T.nan
        let one = T.init(1)
        XCTAssertTrue (nan.isNaN)
        XCTAssertFalse(nan.isZero)
        XCTAssertFalse(nan.isInfinite)
        XCTAssertFalse(nan.isFinite)
        XCTAssertFalse(nan == nan)
        XCTAssertFalse(nan <  0)
        XCTAssertFalse(nan <= 0)
        XCTAssertFalse(nan >= 0)
        XCTAssertFalse(nan >  0)
        XCTAssertTrue ((nan + one).isNaN)
        XCTAssertTrue ((nan - one).isNaN)
        XCTAssertTrue ((nan * one).isNaN)
        XCTAssertTrue ((nan / one).isNaN)
        XCTAssertTrue (nan.squareRoot().isNaN)
    }
    func testBigRatNaN() {
        runNaN(forType: BigRat.self)
        XCTAssertTrue (BigRat.exp(BigRat.nan).isNaN)
    }
    func testIntRatNaN() { runNaN(forType: IntRat.self) }
    //
    func runInf<Q:RationalType>(forType T:Q.Type) {
        let zero = T.init(0)
        let one  = T.init(1)
        let two  = one + one
        let half = one.over(two)
        let inf  = one.over(zero)
        // ±0
        XCTAssert(inf.isInfinite)
        XCTAssertEqual(+zero, -zero)
        XCTAssertEqual((+zero).sign, .plus)
        XCTAssertEqual((-zero).sign, .minus)
        XCTAssertFalse((+zero).isIdentical(to:-zero))
        XCTAssertTrue ((+one/zero).isIdentical(to:+inf))
        XCTAssertTrue ((-one/zero).isIdentical(to:-inf))
        // *(±0, ±inf)
        XCTAssertTrue ((+zero * +inf).isNaN)
        XCTAssertTrue ((-zero * -inf).isNaN)
        XCTAssertTrue ((+zero * +inf).isNaN)
        XCTAssertTrue ((-zero * -inf).isNaN)
        // *(±inf, ±0)
        XCTAssertTrue ((+inf * +zero).isNaN)
        XCTAssertTrue ((-inf * -zero).isNaN)
        XCTAssertTrue ((+inf * +zero).isNaN)
        XCTAssertTrue ((-inf * -zero).isNaN)
        // /(±0, ±inf)
        XCTAssertTrue ((+zero / +inf).isIdentical(to: +zero))
        XCTAssertTrue ((-zero / +inf).isIdentical(to: -zero))
        XCTAssertTrue ((+zero / -inf).isIdentical(to: -zero))
        XCTAssertTrue ((-zero / -inf).isIdentical(to: +zero))
        // /(±0, ±inf)
        XCTAssertEqual (+inf / +zero, +inf)
        XCTAssertEqual (-inf / +zero, -inf)
        XCTAssertEqual (+inf / -zero, -inf)
        XCTAssertEqual (+inf / +zero, +inf)
        // usual cases
        for q in [half, one, two] {
            // *(_, ±inf) and *(±inf, _)
            XCTAssertEqual(+q * +inf, +inf)
            XCTAssertEqual(-q * +inf, -inf)
            XCTAssertEqual(+q * -inf, -inf)
            XCTAssertEqual(-q * -inf, +inf)
            XCTAssertEqual(+inf * +q, +inf)
            XCTAssertEqual(-inf * +q, -inf)
            XCTAssertEqual(+inf * -q, -inf)
            XCTAssertEqual(-inf * -q, +inf)
            // /(_, ±inf)
            XCTAssertTrue ((+q / +inf).isIdentical(to: +zero))
            XCTAssertTrue ((-q / +inf).isIdentical(to: -zero))
            XCTAssertTrue ((+q / -inf).isIdentical(to: -zero))
            XCTAssertTrue ((+q / +inf).isIdentical(to: +zero))
            // +(_, ±inf)
            XCTAssertEqual (+q + +inf, +inf)
            XCTAssertTrue ((-q + +inf).isNaN)
            XCTAssertTrue ((+q + -inf).isNaN)
            XCTAssertEqual (-q + -inf, -inf)
            // +(±inf, _)
            XCTAssertEqual (+inf + +q, +inf)
            XCTAssertTrue ((-inf + +q).isNaN)
            XCTAssertTrue ((+inf + -q).isNaN)
            XCTAssertEqual (-inf + -q, -inf)
        }
    }
    func testBigRatInf() { runInf(forType: BigRat.self) }
    func testIntRatInf() { runInf(forType: IntRat.self) }
    //
    func runRound<Q:RationalType>(forType T:Q.Type) {
        var doubles = [0.0, 0.2, 0.5, 0.8, 1.0, 1.2, 1.5, 1.8]
        doubles += doubles.map{ -$0 }
        for d in doubles {
            let q = Q(d)
            // https://github.com/apple/swift-evolution/blob/master/proposals/0194-derived-collection-of-enum-cases.md
            let allRules:[FloatingPointRoundingRule] = [
                .awayFromZero, .down, .toNearestOrAwayFromZero, .toNearestOrEven, .towardZero, .up
            ]
            for rule in allRules {
                XCTAssertEqual(q.rounded(rule), Q(d.rounded(rule)), "\((d, rule))")
            }
        }
    }
    func testBigRatRound() { runRound(forType: BigRat.self) }
    func testIntRatRound() { runRound(forType: IntRat.self) }
    //
    func runComp<Q:RationalType>(forType T:Q.Type) {
        var doubles = [0.0, 0.5, 1.0, 2.0, .infinity]
        doubles += doubles.map{ -$0 }
        for x in doubles {
            for y in doubles {
                XCTAssertEqual(Q(x) == Q(y), x == y, "\(x) == \(y)")
                XCTAssertEqual(Q(x) <= Q(y), x <= y, "\(x) <= \(y)")
                XCTAssertEqual(Q(x) <  Q(y), x <  y, "\(x) <  \(y)")
                XCTAssertEqual(Q(x) >= Q(y), x >= y, "\(x) >= \(y)")
                XCTAssertEqual(Q(x) >  Q(y), x >  y, "\(x) >  \(y)")
                XCTAssertEqual(
                    Q(x).isTotallyOrdered(belowOrEqualTo:Q(y)),
                    x.isTotallyOrdered(belowOrEqualTo:y),
                    "\(x).isTotallyOrdered(belowOrEqualTo:(\(y))"
                )
            }
        }
    }
    func testBigRatComp() { runComp(forType: BigRat.self) }
    func testIntRatComp() { runComp(forType: IntRat.self) }
    //
    static var allTests = [
        ("testBigRatBasic", testBigRatBasic),
        ("testIntRatBasic", testIntRatBasic),
        ("testBigRatNaN", testBigRatNaN),
        ("testIntRatNaN", testIntRatNaN),
        ("testBigRatInf", testBigRatInf),
        ("testIntRatInf", testIntRatInf),
        ("testBigRatRound", testBigRatRound),
        ("testIntRatRound", testIntRatRound)
    ]
}
