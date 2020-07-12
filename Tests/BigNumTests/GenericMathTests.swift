import XCTest
@testable import BigNum

import Foundation

var okCount = 0

final class GenericMathTests: XCTestCase {
    private typealias D = Double
    func runUnary<R:BigFloatingPoint>(forType T:R.Type, ulp:Int) {
        func ok(_ d:D, _ rd:D, _ rq:R, _ name:String="", check:()->Bool = { false })->Bool {
            okCount += 1
            print("\(R.self).\(name)(\(d.debugDescription))", terminator: " ")
            if rq.isNaN         { print("is NaN");      return rd.isNaN  }
            if rd.isInfinite    { print("D.\(name) is inf"); return true }
            let qrd = T.init(rd)
            if qrd == rq    { print("== D.\(name)"); return true }
            if check()      { print("== inv()");    return true }
            let delta  = Swift.abs(qrd - rq);
            let err    = delta / rq
            let errhex = String(format:"%a", err.asDouble)
            if err <= T.init(D(ulp) * D.ulpOfOne) {
                print("=~ D.\(name) // err=\(errhex)"); return true
            } else {
                print("!~ D.\(name)() // err=\(errhex); FAILED!!"); return false
            }
        }
        let lgfm = D.log(D.greatestFiniteMagnitude) // log of the greatest finite double == 709.78271289338397
        var doubles = [D(1.0)] + [D.ulpOfOne, D.greatestFiniteMagnitude]
        doubles += (1...52).map{ 1 + 1/D(1<<$0)}
        doubles += (1...10).map{ D(1 << $0) }
        doubles += doubles.map { 1.0 / $0 }
        doubles += doubles.map{ -$0 }
        doubles =  doubles.sorted().reduce([]){ $0.contains($1) ? $0 : $0 + [$1] }
        doubles =  [D.nan, -D(0.0), +D(0.0), -D.infinity, +D.infinity] + doubles
        // print(doubles)
        // doubles = []
        for d in doubles {
            let q = T.init(d); var (rd, rq):(D, R)
            // very basic test
            _ = d.isNaN ? XCTAssertEqual(d.isNaN, q.isNaN) : XCTAssertEqual(d, q.asDouble)
            (rd,rq)=(D.sqrt(d), T.sqrt(q,precision:128)); XCTAssert(
                ok(d,rd,rq, "sqrt"), "sqrt(\(d)):\((rd,rq))")
            /*
            (rd,rq)=(D.cbrt(d), T.cbrt(q,precision:128) ); XCTAssert(ok(d,rd,rq, "cbrt" ){ false}, "\((d,rd,rq))")
            */
            (rd,rq)=(D.exp(d),  T.exp(q,precision:128)  ); XCTAssert(ok(d,rd,rq,"exp"){
                d==D.log(rq.asDouble) || lgfm < d.magnitude }, "exp(\(d)):\((rd,rq))")
            (rd,rq)=(D.expMinusOne(d),T.expMinusOne(q));XCTAssert(ok(d,rd,rq,"expMinusOne"){
                d==D.expMinusOne(rq.asDouble) || lgfm < d.magnitude
            }, "expMinusOne(\(d)):\((rd,rq))")
            // logarithms
            (rd,rq)=(D.log(d),  T.log(q,precision:128)  ); XCTAssert(ok(d,rd,rq, "log"){
                d==D.exp  (rq.asDouble)}, "log(\(d)):\((rd,rq))")
            (rd,rq)=(D.log2(d), T.log2(q,precision:128) ); XCTAssert(ok(d,rd,rq, "log2"){
                d==D.pow( 2,rq.asDouble)},"log2(\(d)):\((rd,rq))")
            (rd,rq)=(D.log10(d),T.log10(q,precision:128)); XCTAssert(ok(d,rd,rq, "log10"){
                d==D.pow(10,rq.asDouble)},"log10(\(d)):\((rd,rq))")
            (rd,rq)=(D.log(onePlus:d),T.log1p(q,precision:128)); XCTAssert(
                ok(d,rd,rq, "log1p"){
                    d==D.expMinusOne(rq.asDouble) }, "log1p(\(d)):\((rd,rq))")
            // trigonometric. skip large angles for fixed-width floats because it cannot be normalized
            (rd,rq)=(D.sin(d),  T.sin(q,precision:128)  ); XCTAssert(ok(d,rd,rq, "sin"){
                d==D.asin (rq.asDouble) }, "sin(\(d)):\((rd,rq))")
            (rd,rq)=(D.cos(d),  T.cos(q,precision:128)  ); XCTAssert(ok(d,rd,rq, "cos"){
                d==D.acos (rq.asDouble) }, "cos(\(d)):\((rd,rq))")
            // BigRat.tan(q precision:128) fails for q very close to 1
            (rd,rq)=(D.tan(d),  T.tan(q,precision:96)  ); XCTAssert(ok(d,rd,rq, "tan"){
                d==D.atan (rq.asDouble) }, "tan(\(d)):\((rd,rq))")
            // inverse trigonometric
            (rd,rq)=(D.asin(d), T.asin(q,precision:128) ); XCTAssert(ok(d,rd,rq, "asin" ){d==D.tan  (rq.asDouble)}, "asin(\(d)):\((rd,rq))")
            (rd,rq)=(D.acos(d), T.acos(q,precision:128) ); XCTAssert(ok(d,rd,rq, "acos" ){d==D.cos  (rq.asDouble)}, "acos(\(d)):\((rd,rq))")
            (rd,rq)=(D.atan(d), T.atan(q,precision:128) ); XCTAssert(ok(d,rd,rq, "atan" ){d==D.tan  (rq.asDouble)}, "atan(\(d)):\((rd,rq))")
            // hyperbolic. skip like exp
            (rd,rq)=(D.sinh(d), T.sinh(q,precision:128) ); XCTAssert(ok(d,rd,rq, "sinh" ){
                d==D.asinh(rq.asDouble) ||  lgfm < d.magnitude }, "sinh(\(d)):\((rd,rq))")
            (rd,rq)=(D.cosh(d), T.cosh(q,precision:128) ); XCTAssert(ok(d,rd,rq, "cosh" ){
                lgfm < d.magnitude || d==D.acosh(rq.asDouble) }, "cosh(\(d)):\((rd,rq))")
            (rd,rq)=(D.tanh(d), T.tanh(q,precision:128) ); XCTAssert(ok(d,rd,rq, "tanh" ){d==D.atanh(rq.asDouble)}, "tanh(\(d)):\((rd,rq))")
            // inverse hyperbolic. skip like exp
            (rd,rq)=(D.asinh(d),T.asinh(q,precision:128)); XCTAssert(ok(d,rd,rq, "asinh"){
                d==D.sinh (rq.asDouble)}, "asinh(\(d)):\((rd,rq))")
            (rd,rq)=(D.acosh(d),T.acosh(q,precision:128)); XCTAssert(ok(d,rd,rq, "acosh"){
                d==D.cosh (rq.asDouble)}, "acosh(\(d)):\((rd,rq))")
            (rd,rq)=(D.atanh(d),T.atanh(q,precision:128)); XCTAssert(ok(d,rd,rq, "atanh"){
                d==D.tanh (rq.asDouble)}, "atanh(\(d)):\((rd,rq))")
        }
        print("testUnary:checked \(okCount) cases")
    }
    
    func testUnaryBigRat()   { runUnary(forType: BigRat.self,   ulp:1) }
    func testUnaryBigFloat() { runUnary(forType: BigFloat.self, ulp:1) }

    func runAtan2<R:BigFloatingPoint>(forType T:R.Type) {
        let doubles:[Double] = [-1/0.0, -1.0, -0.0, +0.0, +1.0, +1/0.0]
        debugPrint(doubles)
        for y in doubles {
            for x in doubles {
                XCTAssertEqual(
                    T.atan2(y:T.init(y), x:T.init(x), precision:128).asDouble,
                    D.atan2(y: y, x: x),
                    "\((x, y, T.atan2(y: T.init(y), x: T.init(x))))"
                )
            }
        }
    }
    
    func testAtan2BigRat()   { runAtan2(forType: BigRat.self) }
    func testAtan2BigFloat() { runAtan2(forType: BigFloat.self) }

    static var allTests = [
        ("testAtan2BigRat",   testAtan2BigRat),
        ("testAtan2BigFloat", testAtan2BigFloat),
        ("testUnaryBigRat",   testUnaryBigRat),
        ("testUnaryBigFloat", testUnaryBigFloat),
    ]
}
