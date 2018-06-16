import XCTest
@testable import BigNum

extension BigRational : DoubleConvertible {}
extension BigFloat: DoubleConvertible {}

final class BigNumTests: XCTestCase {
    typealias D = Double
    
    func testNothing() {}
    //
    func runComp<Q:FloatingPoint & DoubleConvertible>(forType T:Q.Type) {
        var doubles = [0.0, 0.5, 1.0, 1.5, 2.0, .infinity]
        doubles += doubles.map{ -$0 }
        for x in doubles {
            for y in doubles {
                XCTAssertEqual(T.init(x) == T.init(y), x == y, "\(x) == \(y)")
                XCTAssertEqual(T.init(x) <= T.init(y), x <= y, "\(x) <= \(y)")
                XCTAssertEqual(T.init(x) <  T.init(y), x <  y, "\(x) <  \(y)")
                XCTAssertEqual(T.init(x) >= T.init(y), x >= y, "\(x) >= \(y)")
                XCTAssertEqual(T.init(x) >  T.init(y), x >  y, "\(x) >  \(y)")
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
    func runArithmetic<Q:FloatingPoint & DoubleConvertible>(forType T:Q.Type) {
        XCTAssertEqual( T.init(3) + T.init(2), T.init(5))
        XCTAssertEqual( T.init(3) - T.init(2), T.init(1))
        XCTAssertEqual( T.init(3) * T.init(2), T.init(6))
        XCTAssertEqual( T.init(3) / T.init(2), T.init(1.5))
        XCTAssertEqual( T.init(+D.pi).asDouble, +D.pi)
        XCTAssertEqual( T.init(-D.pi).asDouble, -D.pi)
    }
    func testBigRatrArithmetic() { runArithmetic(forType: BigRat.self) }
    func testIntRatArithmetic()  { runArithmetic(forType: BigFloat.self) }

    
    static var allTests = [
        ("testNothing", testNothing),
    ]
}
