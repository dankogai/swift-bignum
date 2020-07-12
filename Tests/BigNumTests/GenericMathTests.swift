import XCTest
@testable import BigNum

import Foundation

var okCount = 0

final class GenericMathTests: XCTestCase {
    private typealias D = Double
    func runUnary<R:BigFloatingPoint>(forType T:R.Type) {
        func ok(_ d: D, _ rd: D, _ rq: R, _ name: String = "", _ ulp: Int,
                check:()->Bool = {false})->Bool {
            okCount += 1
            print("\(R.self).\(name)(\(d.debugDescription))", terminator: " ")
            if rq.isNaN {
                print("is NaN")
                return rd.isNaN
            }
            if rd.isInfinite {
                print("\(D.self).\(name)() is inf")
                return true
            }
            let qrd = T.init(rd)
            if qrd == rq {
                print("== \(D.self).\(name)()")
                return true
            }
            if check() {
                print("== f^-1()")
                return true
            }
            let torelance = T.init(D(ulp) * D.ulpOfOne)
            let err = Swift.abs(qrd - rq) / rq
            if err <= torelance {
                print("=~ \(D.self).\(name)()")
                return true
            } else {
                let errhex = String(format: "%a", err.asDouble)
                print("!~ \(D.self).\(name)() // err=\(errhex)")
                return false
            }
        }
        let lgfm = D.log(D.greatestFiniteMagnitude) // 709.78271289338397
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
            let q = T.init(d);
            var (rd, rq): (D, R)
            // very basic test
            _ = d.isNaN ? XCTAssertEqual(d.isNaN, q.isNaN) : XCTAssertEqual(d, q.asDouble)
            // sqrt
            (rd, rq) = (D.sqrt(d), T.sqrt(q, precision: 128));
            XCTAssert(
                ok(d, rd, rq, "sqrt", 1), "sqrt(\(d)):\((rd,rq))")
            /*
            (rd,rq)=(D.cbrt(d), T.cbrt(q,precision:128) ); XCTAssert(ok(d,rd,rq, "cbrt" ){ false}, "\((d,rd,rq))")
            */
            (rd, rq) = (D.exp(d), T.exp(q, precision: 128))
            XCTAssert(ok(d, rd, rq, "exp", 1) {
                d == D.log(rq.asDouble) || lgfm < d.magnitude
            }, "exp(\(d)):\((rd,rq))")
            (rd, rq) = (D.expMinusOne(d), T.expMinusOne(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "expMinusOne", 1) {
                d == D.expMinusOne(rq.asDouble) || lgfm < d.magnitude
            }, "expMinusOne(\(d)):\((rd,rq))")
            // logarithms
            (rd, rq) = (D.log(d), T.log(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "log", 1) {
                d == D.exp(rq.asDouble)
            }, "log(\(d)):\((rd,rq))")
            (rd, rq) = (D.log2(d), T.log2(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "log2", 1) {
                d == D.pow(2, rq.asDouble)
            }, "log2(\(d)):\((rd,rq))")
            (rd, rq) = (D.log10(d), T.log10(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "log10", 1) {
                d == D.pow(10, rq.asDouble)
            }, "log10(\(d)):\((rd,rq))")
            (rd, rq) = (D.log(onePlus: d), T.log1p(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "log1p", 1) {
                d == D.expMinusOne(rq.asDouble)
            }, "log1p(\(d)):\((rd,rq))")
            // trigonometric. skip large angles for fixed-width floats
            // because it cannot be normalized
            (rd, rq) = (D.sin(d), T.sin(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "sin", 1) {
                d == D.asin(rq.asDouble)
            }, "sin(\(d)):\((rd,rq))")
            (rd, rq) = (D.cos(d), T.cos(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "cos", 1) {
                d == D.acos(rq.asDouble)
            }, "cos(\(d)):\((rd,rq))")
            // BigRat.tan(q precision:128) fails for q very close to 1
            (rd, rq) = (D.tan(d), T.tan(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "tan", 1) {
                d == D.atan(rq.asDouble)
            }, "tan(\(d)):\((rd,rq))")
            // inverse trigonometric
            (rd, rq) = (D.asin(d), T.asin(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "asin", 1) {
                d == D.tan(rq.asDouble)
            }, "asin(\(d)):\((rd,rq))")
            (rd, rq) = (D.acos(d), T.acos(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "acos", 1) {
                d == D.cos(rq.asDouble)
            }, "acos(\(d)):\((rd,rq))")
            (rd, rq) = (D.atan(d), T.atan(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "atan", 1) {
                d == D.tan(rq.asDouble)
            }, "atan(\(d)):\((rd,rq))")
            // hyperbolic. skip like exp
            (rd, rq) = (D.sinh(d), T.sinh(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "sinh", 1) {
                d == D.asinh(rq.asDouble) || lgfm < d.magnitude
            }, "sinh(\(d)):\((rd,rq))")
            (rd, rq) = (D.cosh(d), T.cosh(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "cosh", 1) {
                lgfm < d.magnitude || d == D.acosh(rq.asDouble)
            }, "cosh(\(d)):\((rd,rq))")
            (rd, rq) = (D.tanh(d), T.tanh(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "tanh", 1) {
                d == D.atanh(rq.asDouble)
            }, "tanh(\(d)):\((rd,rq))")
            // inverse hyperbolic. skip like exp
            (rd, rq) = (D.asinh(d), T.asinh(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "asinh", 1) {
                d == D.sinh(rq.asDouble)
            }, "asinh(\(d)):\((rd,rq))")
            (rd, rq) = (D.acosh(d), T.acosh(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "acosh", 1) {
                d == D.cosh(rq.asDouble)
            }, "acosh(\(d)):\((rd,rq))")
            (rd, rq) = (D.atanh(d), T.atanh(q, precision: 128));
            XCTAssert(ok(d, rd, rq, "atanh", 1) {
                d == D.tanh(rq.asDouble)
            }, "atanh(\(d)):\((rd,rq))")
        }
        print("testUnary:checked \(okCount) cases")
    }
    
    func testUnaryBigRat()   { runUnary(forType: BigRat.self) }
    func testUnaryBigFloat() { runUnary(forType: BigFloat.self) }

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
