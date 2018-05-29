import XCTest
@testable import BigNum

final class BigRatTests: XCTestCase {
    func testRational() {
        XCTAssertEqual(+2.over(+4), (+1).over(+2))
        XCTAssertEqual(-2.over(+4), (-1).over(+2))
        XCTAssertEqual(+2.over(-4), (-1).over(+2))
        XCTAssertEqual(-2.over(-4), (+1).over(+2))
        XCTAssertEqual( 1.over(2) + 1.over(3), 5.over(6))
        XCTAssertEqual( 1.over(2) - 1.over(3), 1.over(6))
        XCTAssertEqual( 1.over(2) * 1.over(3), 1.over(6))
        XCTAssertEqual( 1.over(2) / 1.over(3), 3.over(2))
    }
    static var allTests = [
        ("testRational", testRational),
    ]
}
