import XCTest
@testable import BigNum

import Foundation

final class GenericMathTests: XCTestCase {
    private typealias D = Double
    private typealias Q = BigRat
    func testUnary () {
        var count = 0
        func ok(_ d:D, _ rd:D, _ rq:Q, _ name:String="", check:()->Bool = { false })->Bool {
            count += 1
            print("BigRat.\(name)(\(d.debugDescription))", terminator: " ")
            if rd.isNaN     { print("is NaN");      return rq.isNaN  }
            let qrd = Q(rd)
            let dname = "Double.\(name)()"
            if qrd == rq    { print("== \(dname)"); return true }
            if check()      { print("== inv()");    return true }
            let delta  = (qrd - rq).magnitude;
            let err    = delta / rq
            let errhex = String(format:"%a", D(err))
            if err <= Q(D.ulpOfOne) {
                print("=~ \(dname) // err=\(errhex)"); return true
            } else {
                print("!~ \(name)() // err=\(errhex); FAILED!!"); return false
            }
        }
        let lgfm = D.log(D.greatestFiniteMagnitude) // log of the greatest finite double == 709.78271289338397
        var doubles = [1.0] + [D.ulpOfOne, D.greatestFiniteMagnitude]
        doubles += (1...52).map{ 1 + 1/D(1<<$0)}
        doubles += (1...10).map{ D(1 << $0) }
        doubles += doubles.map { 1.0 / $0 }
        doubles += doubles.map{ -$0 }
        doubles =  doubles.sorted().reduce([]){ $0.contains($1) ? $0 : $0 + [$1] }
        doubles =  [D.nan, -0.0, +0.0, -D.infinity, +D.infinity] + doubles
        // print(doubles)
        // doubles = []
        for d in doubles {
            let q = Q(d); var (rd, rq):(D, Q)
            _ = d.isNaN ? XCTAssertEqual(d.isNaN, q.isNaN) : XCTAssertEqual(d, q.asDouble) // very basic test
            (rd, rq) = (D.sqrt(d), Q.sqrt(q) ); XCTAssert(ok(d, rd, rq, "sqrt" ){d==D(rq)*D(rq)      }, "\(d)")
            (rd, rq) = (D.cbrt(d), Q.cbrt(q) ); XCTAssert(ok(d, rd, rq, "cbrt" ){d==D(rq)*D(rq)*D(rq)}, "\(d)")
            (rd, rq) = (D.exp(d),  Q.exp(q)  ); XCTAssert(ok(d, rd, rq, "exp"  ){
                lgfm < d.magnitude || d==D.log  (D(rq)) }, "\(d)")
            (rd, rq) = (D.expm1(d),Q.expm1(q)); XCTAssert(ok(d, rd, rq, "exp1m"){
                lgfm < d.magnitude || d==D.log1p(D(rq)) }, "\(d)")
            (rd, rq) = (D.log(d),  Q.log(q)  ); XCTAssert(ok(d, rd, rq, "log"  ){d==D.exp  (D(rq))}, "\(d)")
            (rd, rq) = (D.log2(d), Q.log2(q) ); XCTAssert(ok(d, rd, rq, "log2" ){d==D.pow( 2,D(rq))}, "\(d)")
            (rd, rq) = (D.log10(d),Q.log10(q)); XCTAssert(ok(d, rd, rq, "log10"){d==D.pow(10,D(rq))}, "\(d)")
            (rd, rq) = (D.log1p(d),Q.log1p(q)); XCTAssert(ok(d, rd, rq, "log1p"){d==D.expm1(D(rq))}, "\(d)")
            (rd, rq) = (D.sin(d),  Q.sin(q)  ); XCTAssert(ok(d, rd, rq, "sin"  ){d==D.asin (D(rq))}, "\(d)")
            (rd, rq) = (D.cos(d),  Q.cos(q)  ); XCTAssert(ok(d, rd, rq, "cos"  ){d==D.acos (D(rq))}, "\(d)")
            (rd, rq) = (D.tan(d),  Q.tan(q)  ); XCTAssert(ok(d, rd, rq, "tan"  ){d==D.atan (D(rq))}, "\(d)")
            (rd, rq) = (D.asin(d), Q.asin(q) ); XCTAssert(ok(d, rd, rq, "asin" ){d==D.tan  (D(rq))}, "\(d)")
            (rd, rq) = (D.acos(d), Q.acos(q) ); XCTAssert(ok(d, rd, rq, "acos" ){d==D.cos  (D(rq))}, "\(d)")
            (rd, rq) = (D.atan(d), Q.atan(q) ); XCTAssert(ok(d, rd, rq, "atan" ){d==D.tan  (D(rq))}, "\(d)")
            (rd, rq) = (D.sinh(d), Q.sinh(q) ); XCTAssert(ok(d, rd, rq, "sinh" ){
                lgfm < d.magnitude || d==D.asinh(D(rq)) }, "\(d)")
            (rd, rq) = (D.cosh(d), Q.cosh(q) ); XCTAssert(ok(d, rd, rq, "cosh" ){
                lgfm < d.magnitude || d==D.acosh(D(rq)) }, "\(d)")
            (rd, rq) = (D.tanh(d), Q.tanh(q) ); XCTAssert(ok(d, rd, rq, "tanh" ){d==D.atanh(D(rq))}, "\(d)")
            (rd, rq) = (D.asinh(d),Q.asinh(q)); XCTAssert(ok(d, rd, rq, "asinh"){d==D.sinh (D(rq))}, "\(d)")
            (rd, rq) = (D.acosh(d),Q.acosh(q)); XCTAssert(ok(d, rd, rq, "acosh"){d==D.cosh (D(rq))}, "\(d)")
            (rd, rq) = (D.atanh(d),Q.atanh(q)); XCTAssert(ok(d, rd, rq, "atanh"){d==D.tanh (D(rq))}, "\(d)")
        }
        print("testUnary:checked \(count) cases")
    }
    func testAtan2() {
        let doubles = [-1/0.0, -1.0, -0.0, +0.0, +1.0, +1/0.0]
        debugPrint(doubles)
        for y in doubles {
            for x in doubles {
                XCTAssertEqual(D(Q.atan2(Q(y), Q(x))), D.atan2(y, x), "\(x, y, Q.atan2(Q(y), Q(x)))")
            }
        }
    }
    static var allTests = [
        ("testUnary", testUnary),
        ("testAtan2", testAtan2),
    ]
}
