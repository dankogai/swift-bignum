import XCTest
@testable import BigNum

import Foundation

final class GenericMathTests: XCTestCase {
    private typealias D = Double
    private typealias Q = BigRat
    func testBigRat () {
        func ok(_ d:D, _ rd:D, _ rq:Q, _ name:String="", check:()->Bool = { false })->Bool {
            print("\(name)(\(d)): ", terminator: "")
            if rd.isNaN     { print("NaN");   return rq.isNaN  }
            if Q(rd) == rq  { print("==");    return true }
            if check()      { print("inv()"); return true }
            let err = (Q(rd) - rq).magnitude / rq
            if err <= Q(D.ulpOfOne) {
                print("within 1 ulp"); return true
            }
            print("!!FAIL!! err=\(err.asDouble)")
            return false
        }
        var doubles = [1.0, 1.0+Double.ulpOfOne, 1.0-Double.ulpOfOne]
        doubles += (1...8).map{ D(1 << $0) }
        doubles += [D.ulpOfOne, D.greatestFiniteMagnitude]
        doubles += doubles.map { 1.0 / $0 }
        doubles += doubles.map{ -$0 }
        doubles =  doubles.sorted().reduce([]){ $0.contains($1) ? $0 : $0 + [$1] }
        doubles =  [D.nan, -0.0, +0.0, -D.infinity, +D.infinity] + doubles
        print(doubles)
        for d in doubles {
            let q = Q(d); var (rd, rq):(D, Q)
            (rd, rq) = (D.sqrt(d), Q.sqrt(q) ); XCTAssert(ok(d, rd, rq, "sqrt" ){ D(rq*rq)     == d }, "\(d)")
            (rd, rq) = (D.cbrt(d), Q.cbrt(q) ); XCTAssert(ok(d, rd, rq, "cbrt" ){ D(rq*rq*rq)  == d }, "\(d)")
            (rd, rq) = (D.exp(d),  Q.exp(q)  ); XCTAssert(ok(d, rd, rq, "exp"  ){ D.log  (D(rq))==d }, "\(d)")
            (rd, rq) = (D.expm1(d),Q.expm1(q)); XCTAssert(ok(d, rd, rq, "exp1m"){ D.log1p(D(rq))==d }, "\(d)")
            (rd, rq) = (D.log(d),  Q.log(q)  ); XCTAssert(ok(d, rd, rq, "log"  ){ D.exp  (D(rq))==d }, "\(d)")
            (rd, rq) = (D.log2(d), Q.log2(q) ); XCTAssert(ok(d, rd, rq, "log2" ){ D.pow( 2,D(rq))==d}, "\(d)")
            (rd, rq) = (D.log10(d),Q.log10(q)); XCTAssert(ok(d, rd, rq, "log10"){ D.pow(10,D(rq))==d}, "\(d)")
            (rd, rq) = (D.log1p(d),Q.log1p(q)); XCTAssert(ok(d, rd, rq, "log1p"){ D.expm1(D(rq))==d }, "\(d)")
            (rd, rq) = (D.sin(d),  Q.sin(q)  ); XCTAssert(ok(d, rd, rq, "sin"  ){ D.asin (D(rq))==d }, "\(d)")
            (rd, rq) = (D.cos(d),  Q.cos(q)  ); XCTAssert(ok(d, rd, rq, "cos"  ){ D.acos (D(rq))==d }, "\(d)")
            (rd, rq) = (D.tan(d),  Q.tan(q)  ); XCTAssert(ok(d, rd, rq, "tan"  ){ D.atan (D(rq))==d }, "\(d)")
            (rd, rq) = (D.asin(d), Q.asin(q) ); XCTAssert(ok(d, rd, rq, "asin" ){ D.tan  (D(rq))==d }, "\(d)")
            (rd, rq) = (D.acos(d), Q.acos(q) ); XCTAssert(ok(d, rd, rq, "acos" ){ D.cos  (D(rq))==d }, "\(d)")
            (rd, rq) = (D.atan(d), Q.atan(q) ); XCTAssert(ok(d, rd, rq, "atan" ){ D.tan  (D(rq))==d }, "\(d)")
            (rd, rq) = (D.sinh(d), Q.sinh(q) ); XCTAssert(ok(d, rd, rq, "sinh" ){ D.asinh(D(rq))==d }, "\(d)")
            (rd, rq) = (D.cosh(d), Q.cosh(q) ); XCTAssert(ok(d, rd, rq, "cosh" ){ D.acosh(D(rq))==d }, "\(d)")
            (rd, rq) = (D.tanh(d), Q.tanh(q) ); XCTAssert(ok(d, rd, rq, "tanh" ){ D.atanh(D(rq))==d }, "\(d)")
            (rd, rq) = (D.asinh(d),Q.asinh(q)); XCTAssert(ok(d, rd, rq, "asinh"){ D.sinh (D(rq))==d }, "\(d)")
            (rd, rq) = (D.acosh(d),Q.acosh(q)); XCTAssert(ok(d, rd, rq, "acosh"){ D.cosh (D(rq))==d }, "\(d)")
            (rd, rq) = (D.atanh(d),Q.atanh(q)); XCTAssert(ok(d, rd, rq, "atanh"){ D.tanh (D(rq))==d }, "\(d)")
        }
    }
    
    static var allTests = [
        ("testBigRat", testBigRat),
    ]
}
