import XCTest
@testable import BigNum

final class GenericMathTests: XCTestCase {
    private typealias D = Double
    private typealias Q = BigRat
    func runSpecial<Q:RationalType>(forType T:Q.Type) {
        for q in [T.nan, -T.infinity, +T.infinity, -T.zero, +T.zero] {
            let d = q.asDouble
            XCTAssert(T.sqrt (q).isIdentical(to:T.init(D.sqrt (d))),    "\(d)")
            XCTAssert(T.exp  (q).isIdentical(to:T.init(D.exp  (d))),    "\(d)")
            XCTAssert(T.expm1(q).isIdentical(to:T.init(D.expm1(d))),    "\(d)")
            XCTAssert(T.log  (q).isIdentical(to:T.init(D.log  (d))),    "\(d)")
            XCTAssert(T.log2 (q).isIdentical(to:T.init(D.log2 (d))),    "\(d)")
            XCTAssert(T.log10(q).isIdentical(to:T.init(D.log10(d))),    "\(d)")
            XCTAssert(T.log1p(q).isIdentical(to:T.init(D.log1p(d))),    "\(d)")
            XCTAssert(T.sin  (q).isIdentical(to:T.init(D.sin  (d))),    "\(d)")
            XCTAssert(T.cos  (q).isIdentical(to:T.init(D.cos  (d))),    "\(d)")
            XCTAssert(T.tan  (q).isIdentical(to:T.init(D.tan  (d))),    "\(d)")
            XCTAssert(T.sin  (q).isIdentical(to:T.init(D.asin (d))),    "\(d)")
            XCTAssert(T.acos (q).isIdentical(to:T.init(D.acos (d)))
                                            || T.acos(q) == T.PI()/2,   "\(d)")
            XCTAssert(T.atan (q).isIdentical(to:T.init(D.atan (d)))
                || T.atan(q) == T.PI()/(q.sign == .minus ? -2 : +2),    "\(d)")
            XCTAssert(T.sinh (q).isIdentical(to:T.init(D.sinh (d))),    "\(d)")
            XCTAssert(T.cosh (q).isIdentical(to:T.init(D.cosh (d))),    "\(d)")
            XCTAssert(T.tanh (q).isIdentical(to:T.init(D.tanh (d))),    "\(d)")
            XCTAssert(T.asinh(q).isIdentical(to:T.init(D.asinh(d))),    "\(d)")
            XCTAssert(T.acosh(q).isIdentical(to:T.init(D.acosh(d))),    "\(d)")
            XCTAssert(T.atanh(q).isIdentical(to:T.init(D.atanh(d))),    "\(d)")
       }
    }
    func testSpecial() { runSpecial(forType: BigRat.self) }

    func runNormal<Q:RationalType>(forType T:Q.Type) {
        func ok(_ l:Q, _ rhs:D, _ d:D, inv:(D)->Bool = { _ in false })->Bool {
            let r = Q(rhs)
            if r.isNaN {
                return l.isNaN || !d.isNaN
            }
            return l == r
                || (l - r).magnitude / r <= 2 * Q(D.ulpOfOne)
                || inv(rhs)
        }
        var list = (1...7).map{ D($0) }
        list += list.map { 1.0 / $0 }
        list += [D.ulpOfOne, D.greatestFiniteMagnitude]
        list += list.map{ -$0 }
        list = list.sorted().reduce([]){ $0.contains($1) ? $0 : $0 + [$1] }
        print(list)
        for d in list {
            let q = T.init(d)
            XCTAssert(ok(T.exp  (q), D.exp  (d), d), "\(q, T.exp  (q).asDouble, D.exp  (d))")
            XCTAssert(ok(T.expm1(q), D.expm1(d), d), "\(q, T.expm1(q).asDouble, D.expm1(d))")
            XCTAssert(ok(T.log  (q), D.log  (d), d), "\(q, T.log  (q).asDouble, D.log  (d))")
            XCTAssert(ok(T.log2 (q), D.log2 (d), d), "\(q, T.log2 (q).asDouble, D.log2 (d))")
            XCTAssert(ok(T.log10(q), D.log10(d), d), "\(q, T.log10(q).asDouble, D.log10(d))")
            XCTAssert(ok(T.log1p(q), D.log1p(d), d), "\(q, T.log1p(q).asDouble, D.log1p(d))")
            XCTAssert(ok(T.sin  (q), D.sin  (d), d), "\(q, T.sin  (q).asDouble, D.sin  (d))")
            XCTAssert(ok(T.cos  (q), D.cos  (d), d), "\(q, T.cos  (q).asDouble, D.cos  (d))")
            XCTAssert(ok(T.tan  (q), D.tan  (d), d), "\(q, T.tan  (q).asDouble, D.tan  (d))")
            if d.magnitude != D.ulpOfOne {
                XCTAssert(ok(T.asin (q), D.asin (d), d), "\(q, T.asin (q).asDouble, D.asin (d))")
            }
            XCTAssert(ok(T.acos (q), D.acos (d), d), "\(q, T.acos (q).asDouble, D.acos (d))")
            XCTAssert(ok(T.atan (q), D.atan (d), d), "\(q, T.atan (q).asDouble, D.atan (d))")
            XCTAssert(ok(T.sinh (q), D.sinh (d), d), "\(q, T.sinh (q).asDouble, D.sinh (d))")
            XCTAssert(ok(T.cosh (q), D.cosh (d), d), "\(q, T.cosh (q).asDouble, D.cosh (d))")
            XCTAssert(ok(T.tanh (q), D.tanh (d), d), "\(q, T.tanh (q).asDouble, D.tanh (d))")
            XCTAssert(ok(T.asinh(q), D.asinh(d), d), "\(q, T.asinh(q).asDouble, D.asinh(d))")
            XCTAssert(ok(T.acosh(q), D.acosh(d), d), "\(q, T.acosh(q).asDouble, D.acosh(d))")
            XCTAssert(ok(T.atanh(q), D.atanh(d), d), "\(q, T.atanh(q).asDouble, D.atanh(d))")
         }
    }
    func testNormal() { runNormal(forType: BigRat.self) }

    static var testAll = [
        ("testSpecial", testSpecial),
        ("testNormal",  testNormal),
    ]
}
