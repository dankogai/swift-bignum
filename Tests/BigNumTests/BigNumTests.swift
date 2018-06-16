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
    //
    func runArithmetic<Q:DoubleConvertible & SignedNumeric>(forType T:Q.Type) {
        XCTAssertEqual( T.init(3) + T.init(2), T.init(5))
        XCTAssertEqual( T.init(3) - T.init(2), T.init(1))
        XCTAssertEqual( T.init(3) * T.init(2), T.init(6))
//        XCTAssertEqual( T.init(1,2) / T.init(1, 3), T.init(3, 2))
        XCTAssertEqual( T.init(+Double.pi).asDouble, +Double.pi)
        XCTAssertEqual( T.init(-Double.pi).asDouble, -Double.pi)
    }
    func testBigRatrArithmetic() { runArithmetic(forType: BigRat.self) }
    func testIntRatArithmetic()  { runArithmetic(forType: BigFloat.self) }

    
    static var allTests = [
        ("testNothing", testNothing),
    ]
}
