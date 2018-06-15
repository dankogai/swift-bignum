import XCTest
@testable import BigNum

extension BigRational : DoubleConvertible {}
extension BigFloat: DoubleConvertible {}

final class BigNumTests: XCTestCase {
    func testNothing() {}
    //
    
    func runComp<Q:DoubleConvertible & Comparable>(forType T:Q.Type) {
        var doubles = [0.0, 0.5, 1.0, 1.5, 2.0, .infinity]
        doubles += doubles.map{ -$0 }
        for x in doubles {
            for y in doubles {
                XCTAssertEqual(Q(x) == Q(y), x == y, "\(x) == \(y)")
                XCTAssertEqual(Q(x) <= Q(y), x <= y, "\(x) <= \(y)")
                XCTAssertEqual(Q(x) <  Q(y), x <  y, "\(x) <  \(y)")
                XCTAssertEqual(Q(x) >= Q(y), x >= y, "\(x) >= \(y)")
                XCTAssertEqual(Q(x) >  Q(y), x >  y, "\(x) >  \(y)")
//                XCTAssertEqual(
//                    Q(x).isTotallyOrdered(belowOrEqualTo:Q(y)),
//                    x.isTotallyOrdered(belowOrEqualTo:y),
//                    "\(x).isTotallyOrdered(belowOrEqualTo:(\(y))"
//                )
            }
        }
    }
    func testBigRatComp()   { runComp(forType: BigRat.self) }
    func testBigFloatComp() { runComp(forType: BigFloat.self) }
    //
    static var allTests = [
        ("testNothing", testNothing),
    ]
}
