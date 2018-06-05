import XCTest
@testable import BigNum

final class GenericMathTests: XCTestCase {
    private typealias D = Double
    private typealias Q = BigRat
    func runBigRat<Q:RationalType>(forType T:Q.Type) {
        func ok(_ d:D, _ fd:(D)->D, _ fq:(Q)->Q, inv:(D)->Bool = { _ in false })->Bool {
            let (rd, rq) = (fd(d), fq(Q(d)))
            print(rd, rq)
            return Q(rd).isIdentical(to: rq)
        }
        var doubles = (0...62).map{ D(1 << $0) }
        doubles += doubles.map { 1.0 / $0 }
        doubles += [D.ulpOfOne, D.greatestFiniteMagnitude, D(Float.ulpOfOne), D(Float.greatestFiniteMagnitude)]
        doubles += doubles.map{ -$0 }
        doubles = doubles.sorted().reduce([]){ $0.contains($1) ? $0 : $0 + [$1] }
        for d in [D.nan, -0.0, +0.0, -D.infinity, +D.infinity] + doubles {
            // print("testing \(d)")
            XCTAssert(ok(d, D.exp,   T.exp),   "\(d)")
            XCTAssert(ok(d, D.expm1, T.expm1), "\(d)")
            XCTAssert(ok(d, D.log,   T.log  ), "\(d)")
            XCTAssert(ok(d, D.log2,  T.log2 ), "\(d)")
            XCTAssert(ok(d, D.log10, T.log10), "\(d)")
            XCTAssert(ok(d, D.log1p, T.log1p), "\(d)")
            XCTAssert(ok(d, D.sin,   T.sin  ), "\(d)")
            XCTAssert(ok(d, D.cos,   T.cos  ), "\(d)")
            XCTAssert(ok(d, D.tan,   T.tan  ), "\(d)")
            XCTAssert(ok(d, D.asin,  T.asin ), "\(d)")
            XCTAssert(ok(d, D.acos,  T.acos ), "\(d)")
            XCTAssert(ok(d, D.atan,  T.atan ), "\(d)")
            XCTAssert(ok(d, D.sinh,  T.sinh ), "\(d)")
            XCTAssert(ok(d, D.cosh,  T.cosh ), "\(d)")
            XCTAssert(ok(d, D.tanh,  T.tanh ), "\(d)")
            XCTAssert(ok(d, D.asinh, T.asinh), "\(d)")
            XCTAssert(ok(d, D.acosh, T.acosh), "\(d)")
            XCTAssert(ok(d, D.atanh, T.atanh), "\(d)")
         }
    }
    func testBigRat() { runBigRat(forType: BigRat.self) }

    static var testAll = [
        ("testBigRat", testBigRat),
    ]
}
