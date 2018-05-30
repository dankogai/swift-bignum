import XCTest
@testable import BigNum

final class BigRatTests: XCTestCase {
    //
    func runRatBasic<Q:RationalType>(forType T:Q.Type) {
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
    func testBigRatBasic() { runRatBasic(forType: BigRat.self) }
    func testIntRatBasic() { runRatBasic(forType: IntRat.self) }
    //
    func runRatNaN<Q:RationalType>(forType T:Q.Type) {
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
        runRatNaN(forType: BigRat.self)
        XCTAssertTrue (BigRat.exp(BigRat.nan).isNaN)
    }
    func testIntRatNaN() { runRatNaN(forType: IntRat.self) }
    //
    func runRatInf<Q:RationalType>(forType T:Q.Type) {
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
        XCTAssertNotEqual((+zero).sign, (-zero).sign)
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
        XCTAssertEqual (+zero / +inf, zero)
        XCTAssertEqual((+zero / +inf).sign, .plus)
        XCTAssertEqual (-zero / +inf, zero)
        XCTAssertEqual((-zero / +inf).sign, .minus)
        XCTAssertEqual (+zero / -inf, zero)
        XCTAssertEqual((+zero / -inf).sign, .minus)
        XCTAssertEqual (-zero / -inf, zero)
        XCTAssertEqual((-zero / -inf).sign, .plus)
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
            XCTAssertEqual (+q / +inf, zero)
            XCTAssertEqual((+q / +inf).sign, .plus)
            XCTAssertEqual (-q / +inf, zero)
            XCTAssertEqual((-q / +inf).sign, .minus)
            XCTAssertEqual (+q / -inf, zero)
            XCTAssertEqual((+q / -inf).sign, .minus)
            XCTAssertEqual (-q / -inf, zero)
            XCTAssertEqual((-q / -inf).sign, .plus)
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
    func testBigRatInf() { runRatInf(forType: BigRat.self) }
    func testIntRatInf() { runRatInf(forType: IntRat.self) }
    //
    static var testAll = [
        ("testBigRatBasic", testBigRatBasic),
        ("testIntRatBasic", testIntRatBasic),
        ("testBigRatNaN", testBigRatNaN),
        ("testIntRatNaN", testIntRatNaN),
        ("testBigRatInf", testBigRatInf),
        ("testIntRatInf", testIntRatInf),
    ]
}
