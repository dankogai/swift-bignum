import XCTest
@testable import BigNum

extension BigRational : DoubleConvertible {}
extension BigFloat: DoubleConvertible {}

final class BigNumTests: XCTestCase {
    typealias D = Double
    
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
                XCTAssertEqual(
                    Q(x).isTotallyOrdered(belowOrEqualTo:Q(y)),
                    x.isTotallyOrdered(belowOrEqualTo:y),
                    "\(x).isTotallyOrdered(belowOrEqualTo:(\(y))"
                )
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
    func testBigRatArithmetic() { runArithmetic(forType: BigRat.self) }
    func testBigFloatArithmetic()  { runArithmetic(forType: BigFloat.self) }
    //
    func runRound<Q:FloatingPoint & DoubleConvertible>(forType T:Q.Type) {
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
    func testBigRatRound() { runArithmetic(forType: BigRat.self) }
    func testBigFloatRound()  { runArithmetic(forType: BigFloat.self) }

    static var allTests = [
        ("testBigRatComp", testBigRatComp),
        ("testBigFloatComp", testBigFloatComp),
        ("testBigRatArithmetic", testBigRatArithmetic),
        ("testBigFloatArithmetic", testBigFloatArithmetic),
    ]
}
