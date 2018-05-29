import XCTest
@testable import BigNum

final class BigRatTests: XCTestCase {
    private typealias BI = BigInt
    func testConv() {
        XCTAssertEqual(BigRat(+Double.pi).asDouble, +Double.pi)
        XCTAssertEqual(BigRat(-Double.pi).asDouble, -Double.pi)
    }
    func testIntRatOps() {
        XCTAssertEqual(+2.over(+4), (+1).over(+2))
        XCTAssertEqual(-2.over(+4), (-1).over(+2))
        XCTAssertEqual(+2.over(-4), (-1).over(+2))
        XCTAssertEqual(-2.over(-4), (+1).over(+2))
        XCTAssertEqual( 1.over(2) + 1.over(3), 5.over(6))
        XCTAssertEqual( 1.over(2) - 1.over(3), 1.over(6))
        XCTAssertEqual( 1.over(2) * 1.over(3), 1.over(6))
        XCTAssertEqual( 1.over(2) / 1.over(3), 3.over(2))
    }
    func testBigRatOps() {
        XCTAssertEqual(+BI(2).over(+4), BI(+1).over(+2))
        XCTAssertEqual(-BI(2).over(+4), BI(-1).over(+2))
        XCTAssertEqual(+BI(2).over(-4), BI(-1).over(+2))
        XCTAssertEqual(-BI(2).over(-4), BI(+1).over(+2))
        XCTAssertEqual( BI(1).over(2) + BI(1).over(3), BI(5).over(6))
        XCTAssertEqual( BI(1).over(2) - BI(1).over(3), BI(1).over(6))
        XCTAssertEqual( BI(1).over(2) * BI(1).over(3), BI(1).over(6))
        XCTAssertEqual( BI(1).over(2) / BI(1).over(3), BI(3).over(2))
    }
    static var testAll = [
        ("testConv", testConv),
        ("testIntRatOps", testIntRatOps),
        ("testBigRatOps", testBigRatOps),
    ]
}
