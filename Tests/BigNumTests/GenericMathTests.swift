import XCTest
@testable import BigNum

import Foundation

final class GenericMathTests: XCTestCase {
    private typealias D = Double
    private typealias Q = BigRat
    
    func testBigRat () {
        func ok(_ d:D, _ q:Q, _ name:String="")->Bool {
            if d.isNaN      { return q.isNaN }
            if Q(d) == q    { return true }
            let err = (Q(d) - q).magnitude / q
            if err < 2 * Q(D.ulpOfOne) { return true }
            print("d=\(d), q=\(q), err=\(err.asDouble)");
            return false
        }
        var doubles = (0...2).map{ D(1 << $0) }  // + [D.greatestFiniteMagnitude]
        doubles += doubles.map { 1.0 / $0 }
        doubles += doubles.map{ -$0 }
        doubles = doubles.sorted().reduce([]){ $0.contains($1) ? $0 : $0 + [$1] }
        for d in [D.nan, -0.0, +0.0, -D.infinity, +D.infinity] + doubles {
            let q = Q(d); var (rd, rq):(D, Q)
            print("exp(\(d))"  ); (rd, rq) = (D.exp(d),  Q.exp(q)  ); XCTAssert(ok(rd, rq), "\(d)")
            print("exp1m(\(d))"); (rd, rq) = (D.expm1(d),Q.expm1(q)); XCTAssert(ok(rd, rq), "\(d)")
            print("log(\(d))"  ); (rd, rq) = (D.log(d),  Q.log(q)  ); XCTAssert(ok(rd, rq), "\(d)")
            print("log2(\(d))" ); (rd, rq) = (D.log2(d), Q.log2(q) ); XCTAssert(ok(rd, rq), "\(d)")
            print("log10(\(d))"); (rd, rq) = (D.log10(d),Q.log10(q)); XCTAssert(ok(rd, rq), "\(d)")
            print("log1p(\(d))"); (rd, rq) = (D.log1p(d),Q.log1p(q)); XCTAssert(ok(rd, rq), "\(d)")
            print("sin(\(d))"  ); (rd, rq) = (D.sin(d),  Q.sin(q)  ); XCTAssert(ok(rd, rq), "\(d)")
            print("cos(\(d))"  ); (rd, rq) = (D.cos(d),  Q.cos(q)  ); XCTAssert(ok(rd, rq), "\(d)")
            print("tan(\(d))"  ); (rd, rq) = (D.tan(d),  Q.tan(q)  ); XCTAssert(ok(rd, rq), "\(d)")
            print("asin(\(d))" ); (rd, rq) = (D.asin(d), Q.asin(q) ); XCTAssert(ok(rd, rq), "\(d)")
            print("acos(\(d))" ); (rd, rq) = (D.acos(d), Q.acos(q) ); XCTAssert(ok(rd, rq), "\(d)")
            print("atan(\(d))" ); (rd, rq) = (D.atan(d), Q.atan(q) ); XCTAssert(ok(rd, rq), "\(d)")
            print("sinh(\(d))" ); (rd, rq) = (D.sinh(d), Q.sinh(q) ); XCTAssert(ok(rd, rq), "\(d)")
            print("cosh(\(d))" ); (rd, rq) = (D.cosh(d), Q.cosh(q) ); XCTAssert(ok(rd, rq), "\(d)")
            print("tanh(\(d))" ); (rd, rq) = (D.tanh(d), Q.tanh(q) ); XCTAssert(ok(rd, rq), "\(d)")
            print("asinh(\(d))"); (rd, rq) = (D.asinh(d),Q.asinh(q)); XCTAssert(ok(rd, rq), "\(d)")
            print("acosh(\(d))"); (rd, rq) = (D.acosh(d),Q.acosh(q)); XCTAssert(ok(rd, rq), "\(d)")
            print("atanh(\(d))"); (rd, rq) = (D.atanh(d),Q.atanh(q)); XCTAssert(ok(rd, rq), "\(d)")
        }
    }
    
    static var testAll = [
        ("testBigRat", testBigRat),
    ]
}
