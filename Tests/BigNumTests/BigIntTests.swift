import Testing
import Foundation   // JSONEncoder, for the Codable round trip
@testable import BigNum

///
/// `BigUInt` and `BigInt` against the one oracle that cannot be wrong: the
/// fixed-width integers they generalize.  Every value used here fits in `Int`
/// (or `Int128`) so the expected answer is whatever the stdlib says, and the
/// wide cases are pinned by identities instead -- `(a*b + r)/b == a` and
/// friends -- since there is nothing left to compare them to.
///
@Suite struct BigIntTests {

    /// SplitMix64, so a failure is reproducible from its seed alone.
    struct Random {
        var state:UInt64
        init(seed:UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        /// Deliberately biased toward small magnitudes and toward the limb
        /// boundaries, where the carries live.
        mutating func int() -> Int {
            let raw = next()
            switch raw % 8 {
            case 0:  return 0
            case 1:  return Int(truncatingIfNeeded: raw >> 3) % 4
            case 2:  return Int(truncatingIfNeeded: raw) % 0x1_0000
            case 3:  return Int.max - Int(raw % 4)
            case 4:  return Int.min + Int(raw % 4)
            default: return Int(truncatingIfNeeded: raw)
            }
        }
        mutating func uint() -> UInt {
            let raw = next()
            switch raw % 6 {
            case 0:  return 0
            case 1:  return UInt(raw % 4)
            case 2:  return UInt.max - UInt(raw % 4)
            default: return UInt(raw)
            }
        }
        /// A `BigInt` several limbs wide.
        mutating func big(limbs n:Int) -> BigInt {
            var v = BigInt(0)
            for _ in 0 ..< n { v = (v << UInt.bitWidth) | BigInt(next()) }
            return next() & 1 == 0 ? v : -v
        }
    }

    static let seeds:[UInt64] = [1, 0xDEADBEEF, 0x0123456789ABCDEF, 12345]

    // MARK: - the invariant everything else rests on

    /// Normalization has to make the representation canonical, or `==` (which
    /// compares limbs) reports two spellings of the same number as different.
    func checkCanonical(_ v:BigInt, _ what:String) {
        if let top = v.limbs.last {
            #expect(v.limbs.count > 0)
            if v.limbs.count == 1 {
                #expect(top != 0, "\(what): a lone zero limb should have been dropped")
            } else {
                let below = v.limbs[v.limbs.count - 2] >> (UInt.bitWidth - 1)
                #expect(!(top == 0 && below == 0),
                        "\(what): redundant zero sign limb in \(v.limbs)")
                #expect(!(top == UInt.max && below == 1),
                        "\(what): redundant all-ones sign limb in \(v.limbs)")
            }
        }
    }

    @Test func canonicalForm() {
        // every spelling of zero has to collapse to the same empty array
        #expect(BigInt(0).limbs.isEmpty)
        #expect((-BigInt(0)).limbs.isEmpty)
        #expect((BigInt(7) - BigInt(7)).limbs.isEmpty)
        #expect((BigInt(0) * BigInt(-5)).limbs.isEmpty)
        #expect(BigUInt(0).limbs.isEmpty)
        // -1 is the one negative that fits in a single all-ones limb
        #expect(BigInt(-1).limbs == [UInt.max])
        #expect(BigInt(1).limbs == [1])
        // a positive value whose top bit is set needs a clear sign limb, and
        // that limb must not then be mistaken for padding
        #expect(BigInt(1) << (UInt.bitWidth - 1) == BigInt(UInt(1) << (UInt.bitWidth - 1)))
        #expect((BigInt(1) << (UInt.bitWidth - 1)).limbs == [UInt(1) << (UInt.bitWidth - 1), 0])
        #expect((BigInt(-1) << (UInt.bitWidth - 1)).limbs == [UInt(1) << (UInt.bitWidth - 1)])
    }

    // MARK: - arithmetic against Int

    /// `Int128` would be the natural wider oracle, but it needs macOS 15 and this
    /// package deploys to 14 -- so where `Int` overflows, the identity
    /// `(a op b) inverse b == a` stands in for it.
    @Test(arguments: seeds)
    func arithmeticAgainstInt(_ seed:UInt64) {
        var rng = Random(seed: seed)
        for _ in 0 ..< 2000 {
            let (a, b) = (rng.int(), rng.int())
            let (x, y) = (BigInt(a), BigInt(b))
            let sum = a.addingReportingOverflow(b)
            if !sum.overflow { #expect(x + y == BigInt(sum.partialValue), "\(a) + \(b)") }
            #expect((x + y) - y == x, "(\(a) + \(b)) - \(b)")
            let difference = a.subtractingReportingOverflow(b)
            if !difference.overflow {
                #expect(x - y == BigInt(difference.partialValue), "\(a) - \(b)")
            }
            #expect((x - y) + y == x, "(\(a) - \(b)) + \(b)")
            let product = a.multipliedReportingOverflow(by: b)
            if !product.overflow {
                #expect(x * y == BigInt(product.partialValue), "\(a) * \(b)")
            }
            #expect((x * y).magnitude == x.magnitude * y.magnitude, "|\(a) * \(b)|")
            if a != Int.min { #expect(-x == BigInt(-a), "-\(a)") }
            #expect(~x == BigInt(~a), "~\(a)")
            #expect(x.magnitude == BigUInt(a.magnitude), "|\(a)|")
            #expect((x < y) == (a < b), "\(a) < \(b)")
            #expect((x == y) == (a == b), "\(a) == \(b)")
            #expect(x.signum() == BigInt(a.signum()), "signum \(a)")
            checkCanonical(x + y, "\(a) + \(b)")
            checkCanonical(x * y, "\(a) * \(b)")
            // Int traps on Int.min / -1; BigInt has the room for it
            if b != 0 && !(a == Int.min && b == -1) {
                let (q, r) = a.quotientAndRemainder(dividingBy: b)
                #expect(x / y == BigInt(q), "\(a) / \(b)")
                #expect(x % y == BigInt(r), "\(a) % \(b)")
                // the sign contract: quotient toward zero, remainder like the
                // dividend
                #expect((x % y).isNegative == (r < 0), "sign of \(a) % \(b)")
                checkCanonical(x / y, "\(a) / \(b)")
                checkCanonical(x % y, "\(a) % \(b)")
            }
        }
    }

    @Test(arguments: seeds)
    func bitwiseAndShiftsAgainstInt(_ seed:UInt64) {
        var rng = Random(seed: seed)
        for _ in 0 ..< 2000 {
            let (a, b) = (rng.int(), rng.int())
            let (x, y) = (BigInt(a), BigInt(b))
            #expect(x & y == BigInt(a & b), "\(a) & \(b)")
            #expect(x | y == BigInt(a | b), "\(a) | \(b)")
            #expect(x ^ y == BigInt(a ^ b), "\(a) ^ \(b)")
            checkCanonical(x & y, "\(a) & \(b)")
            checkCanonical(x | y, "\(a) | \(b)")
            checkCanonical(x ^ y, "\(a) ^ \(b)")
            for k in [0, 1, 2, 31, 62, 63, 64, 65, 127, 128, 200] {
                // Int's >> is arithmetic and saturates to 0/-1, and so is ours
                #expect(x >> k == BigInt(a >> k), "\(a) >> \(k)")
                checkCanonical(x >> k, "\(a) >> \(k)")
                // Int's << overflows, so check against a shift-then-shift-back
                let up = x << k
                checkCanonical(up, "\(a) << \(k)")
                #expect(up >> k == x, "\(a) << \(k) >> \(k)")
                #expect(up == x * BigInt(2).power(k), "\(a) << \(k) == \(a) * 2^\(k)")
            }
            // a negative shift count reverses the direction
            #expect(x << -3 == x >> 3, "\(a) << -3")
            #expect(x >> -3 == x << 3, "\(a) >> -3")
        }
    }

    @Test(arguments: seeds)
    func widthsAgainstInt(_ seed:UInt64) {
        var rng = Random(seed: seed)
        for _ in 0 ..< 2000 {
            let a = rng.int()
            let x = BigInt(a)
            // bitWidth counts the magnitude's significant bits plus a sign bit,
            // and zero is 0 bits wide
            let expected = a == 0 ? 0 : (Int.bitWidth - a.magnitude.leadingZeroBitCount) + 1
            #expect(x.bitWidth == expected, "bitWidth of \(a)")
            #expect(x.trailingZeroBitCount == (a == 0 ? 0 : a.trailingZeroBitCount),
                    "trailingZeroBitCount of \(a)")
            // words is the two's complement representation, which for anything
            // this size is exactly Int's own
            #expect(Array(x.words) == Array(a.words), "words of \(a)")
            #expect(Int(x) == a, "Int(BigInt(\(a)))")
            #expect(Int(exactly: x) == a, "Int(exactly: BigInt(\(a)))")
            if 0 <= a {
                #expect(BigUInt(a).bitWidth == Int.bitWidth - a.leadingZeroBitCount,
                        "BigUInt bitWidth of \(a)")
            }
        }
    }

    // MARK: - wide values, where identities are the only oracle

    @Test(arguments: seeds)
    func wideArithmeticIdentities(_ seed:UInt64) {
        var rng = Random(seed: seed)
        for _ in 0 ..< 60 {
            let a = rng.big(limbs: 1 + Int(rng.next() % 6))
            let b = rng.big(limbs: 1 + Int(rng.next() % 6))
            checkCanonical(a, "generated a")
            checkCanonical(b, "generated b")
            #expect((a + b) - b == a)
            #expect((a - b) + b == a)
            #expect(-(-a) == a)
            #expect(~(~a) == a)
            #expect(~a == -a - 1)                       // the two's complement identity
            #expect((a * b).magnitude == a.magnitude * b.magnitude)
            if !b.isZero {
                let (q, r) = a.quotientAndRemainder(dividingBy: b)
                #expect(q * b + r == a, "\(a) = \(q)*\(b) + \(r)")
                #expect(r.magnitude < b.magnitude, "remainder out of range")
                #expect(r.isZero || r.isNegative == a.isNegative, "remainder sign")
                checkCanonical(q, "quotient")
                checkCanonical(r, "remainder")
            }
            // (a*b + r) / b recovers a exactly, which is Algorithm D's whole job
            if !b.isZero {
                let r = rng.big(limbs: 1).magnitude % b.magnitude
                let n = a * b + BigInt(r)
                #expect(n / b == a || (n / b - a).magnitude <= 1, "reconstruct \(a)")
            }
        }
    }

    /// Karatsuba only engages above `_karatsubaLimit` limbs, so this is the only
    /// test that reaches it -- and it has to agree with schoolbook exactly.
    @Test func karatsubaMatchesSchoolbook() {
        var rng = Random(seed: 0xC0FFEE)
        for count in [_karatsubaLimit, _karatsubaLimit + 1, 2 * _karatsubaLimit + 3] {
            let a = (0 ..< count).map { _ in UInt(rng.next()) }
            let b = (0 ..< count).map { _ in UInt(rng.next()) }
            #expect(_multiply(a, b) == schoolbook(a, b), "\(count)-limb product")
        }
        // and the identity still has to hold at that size
        let x = rng.big(limbs: _karatsubaLimit + 7)
        let y = rng.big(limbs: _karatsubaLimit + 3)
        #expect((x * y) / y == x)
        #expect((x * y) % y == 0)
    }

    // MARK: - division against a reference that cannot be subtly wrong

    /// Restoring binary long division: one bit at a time, using only shifts,
    /// comparison and subtraction, so it shares no reasoning with Algorithm D.
    func referenceDivide(_ a:BigUInt, _ b:BigUInt) -> (quotient:BigUInt, remainder:BigUInt) {
        precondition(!b.isZero)
        var (q, r) = (BigUInt(0), BigUInt(0))
        var i = a.bitWidth - 1
        while 0 <= i {
            r = (r << 1) | ((a >> i) & 1)
            q <<= 1
            if b <= r { r -= b ; q |= 1 }
            i -= 1
        }
        return (q, r)
    }

    /// Algorithm D's quotient estimate is worst when the divisor's leading limbs
    /// sit at the extremes, and when the true quotient limb is 0, 1 or the largest
    /// a limb can hold.  These are the inputs that walk the estimate down, and
    /// -- if it is ever off by one -- the ones that make it add the divisor back.
    @Test func divisionAgainstReference() {
        var rng = Random(seed: 0xD1D1DE)
        let interesting:[UInt] = [
            0, 1, 2, UInt.max, UInt.max - 1,
            UInt(1) << (UInt.bitWidth - 1),         // exactly half a limb
            (UInt(1) << (UInt.bitWidth - 1)) + 1,
            UInt.max >> 1,
        ]
        var divisors:[BigUInt] = []
        for top in interesting where top != 0 {
            for second in interesting {
                divisors.append(BigUInt(limbs: [second, top]))
                divisors.append(BigUInt(limbs: [1, second, top]))
                divisors.append(BigUInt(limbs: [second, 0, top]))
            }
        }
        for _ in 0 ..< 20 { divisors.append(rng.big(limbs: 3).magnitude) }
        var checked = 0
        for v in divisors where !v.isZero {
            var dividends:[BigUInt] = []
            for q in interesting {
                for delta in [BigUInt(0), BigUInt(1), v - 1] {
                    dividends.append(v * BigUInt(q) + delta)
                    dividends.append(v * (BigUInt(q) << UInt.bitWidth) + delta)
                }
            }
            dividends.append(v - 1)
            dividends.append(rng.big(limbs: 5).magnitude)
            for u in dividends {
                let got = u.quotientAndRemainder(dividingBy: v)
                let want = referenceDivide(u, v)
                #expect(got.quotient == want.quotient, "\(u) / \(v)")
                #expect(got.remainder == want.remainder, "\(u) % \(v)")
                #expect(got.quotient * v + got.remainder == u, "\(u) reconstruct")
                #expect(got.remainder < v, "\(u) % \(v) out of range")
                checked += 1
            }
        }
        #expect(2000 < checked, "only \(checked) divisions exercised")
    }

    /// The plain O(n²) product, kept here so the test does not depend on the
    /// implementation it is checking.
    func schoolbook(_ a:[UInt], _ b:[UInt]) -> [UInt] {
        var r = [UInt](repeating: 0, count: a.count + b.count)
        for i in 0 ..< a.count {
            var carry:UInt = 0
            for j in 0 ..< b.count {
                let (high, low) = a[i].multipliedFullWidth(by: b[j])
                let (s1, o1) = r[i+j].addingReportingOverflow(low)
                let (s2, o2) = s1.addingReportingOverflow(carry)
                r[i+j] = s2
                carry = high &+ (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
            }
            var k = i + b.count
            while carry != 0 && k < r.count {
                let (s, o) = r[k].addingReportingOverflow(carry)
                r[k] = s
                carry = o ? 1 : 0
                k += 1
            }
        }
        while r.last == 0 { r.removeLast() }
        return r
    }

    // MARK: - unsigned

    @Test(arguments: seeds)
    func unsignedAgainstUInt(_ seed:UInt64) {
        var rng = Random(seed: seed)
        for _ in 0 ..< 2000 {
            let (a, b) = (rng.uint(), rng.uint())
            let (x, y) = (BigUInt(a), BigUInt(b))
            let sum = a.addingReportingOverflow(b)
            if !sum.overflow { #expect(x + y == BigUInt(sum.partialValue), "\(a) + \(b)") }
            #expect((x + y) - y == x, "(\(a) + \(b)) - \(b)")
            let (high, low) = a.multipliedFullWidth(by: b)
            #expect(x * y == BigUInt(limbs: [low, high]), "\(a) * \(b)")
            if b <= a { #expect(x - y == BigUInt(a - b), "\(a) - \(b)") }
            if b != 0 {
                #expect(x / y == BigUInt(a / b), "\(a) / \(b)")
                #expect(x % y == BigUInt(a % b), "\(a) % \(b)")
            }
            #expect((x < y) == (a < b), "\(a) < \(b)")
            #expect(x.bitWidth == UInt.bitWidth - a.leadingZeroBitCount, "bitWidth \(a)")
            #expect(UInt(x) == a, "UInt(BigUInt(\(a)))")
        }
    }

    // MARK: - square root, gcd, power

    @Test func squareRootSmall() {
        for n in 0 ..< 2000 {
            let r = BigUInt(n).squareRoot()
            #expect(r * r <= BigUInt(n), "√\(n) too big")
            #expect((r+1) * (r+1) > BigUInt(n), "√\(n) too small")
            #expect(BigInt(n).squareRoot() == BigInt(r), "BigInt √\(n)")
        }
        // exact squares and the values either side of them, across the limb
        // boundary where a Double estimate would go wrong
        for k in [31, 32, 33, 63, 64, 65, 100, 200] {
            let root = BigUInt(1) << k
            let square = root * root
            #expect(square.squareRoot() == root, "√(2^\(2*k))")
            #expect((square - 1).squareRoot() == root - 1, "√(2^\(2*k) - 1)")
            #expect((square + 1).squareRoot() == root, "√(2^\(2*k) + 1)")
        }
        #expect(UInt.max == UInt(BigUInt(UInt.max)))
        let m = BigUInt(UInt.max)
        #expect(m.squareRoot() == BigUInt(UInt(4294967295)) || UInt.bitWidth != 64)
    }

    /// Textbook Euclid on `UInt` -- a second, independent implementation, so a
    /// shared misconception cannot make both agree.
    func gcdOracle(_ a:UInt, _ b:UInt) -> UInt {
        var (x, y) = (a, b)
        while y != 0 { (x, y) = (y, x % y) }
        return x
    }

    @Test(arguments: seeds)
    func gcdAgainstInt(_ seed:UInt64) {
        var rng = Random(seed: seed)
        for _ in 0 ..< 2000 {
            let (a, b) = (rng.int(), rng.int())
            let g = BigInt(a).greatestCommonDivisor(with: BigInt(b))
            #expect(!g.isNegative, "gcd(\(a), \(b)) went negative")
            #expect(g == BigInt(gcdOracle(a.magnitude, b.magnitude)), "gcd(\(a), \(b))")
            #expect(BigUInt(a.magnitude).greatestCommonDivisor(with: BigUInt(b.magnitude))
                      == BigUInt(gcdOracle(a.magnitude, b.magnitude)), "unsigned gcd(\(a), \(b))")
        }
        // wide values, where the only check is the definition itself
        for _ in 0 ..< 40 {
            let (a, b) = (rng.big(limbs: 4), rng.big(limbs: 3))
            let g = a.greatestCommonDivisor(with: b)
            if g.isZero { #expect(a.isZero && b.isZero) ; continue }
            #expect(a % g == 0 && b % g == 0, "gcd(\(a), \(b)) does not divide both")
            // maximal iff the two cofactors are coprime
            #expect((a/g).greatestCommonDivisor(with: b/g) == 1, "gcd(\(a), \(b)) not maximal")
        }
    }

    @Test func powerAndSquareRootEdges() {
        #expect(BigInt(2).power(0) == 1)
        #expect(BigInt(2).power(1) == 2)
        #expect(BigInt(2).power(64) == BigInt(1) << 64)
        #expect(BigInt(-2).power(3) == -8)
        #expect(BigInt(-2).power(4) == 16)
        #expect(BigInt(10).power(30) == BigInt("1000000000000000000000000000000")!)
        #expect(BigUInt(10).power(30) == BigUInt("1000000000000000000000000000000")!)
        // negative exponents have no integral answer except for ±1.  The
        // unsigned case must reach that conclusion without evaluating `0 - 1`.
        #expect(BigUInt(5).power(-2) == 0)
        #expect(BigUInt(1).power(-2) == 1)
        #expect(BigInt(5).power(-2) == 0)
        #expect(BigInt(1).power(-9) == 1)
        #expect(BigInt(-1).power(-9) == -1)
        #expect(BigInt(-1).power(-8) == 1)
        #expect(BigInt(0).squareRoot() == 0)
    }

    // MARK: - strings

    @Test(arguments: seeds)
    func radixRoundTrip(_ seed:UInt64) {
        var rng = Random(seed: seed)
        for _ in 0 ..< 200 {
            let v = rng.big(limbs: 1 + Int(rng.next() % 5))
            for radix in [2, 8, 10, 16, 36] {
                let s = v.toString(radix: radix, uppercase: false)
                #expect(BigInt(s, radix: radix) == v, "\(s) in radix \(radix)")
                let u = v.toString(radix: radix, uppercase: true)
                #expect(BigInt(u, radix: radix) == v, "\(u) uppercase in radix \(radix)")
            }
            #expect(BigInt(v.description) == v, "description round trip")
            // and it has to agree with the stdlib's own formatter
            #expect(v.toString(radix: 10) == String(v, radix: 10))
            #expect(v.magnitude.toString(radix: 16) == String(v.magnitude, radix: 16))
        }
    }

    @Test func stringsAgainstInt() {
        for a in [0, 1, -1, 7, -7, 255, -255, Int.max, Int.min + 1] {
            for radix in [2, 8, 10, 16, 36] {
                #expect(BigInt(a).toString(radix: radix) == String(a, radix: radix),
                        "\(a) in radix \(radix)")
            }
        }
        #expect(BigInt("0") == 0)
        #expect(BigInt("-0") == 0)
        #expect(BigInt("+42") == 42)
        #expect(BigInt("ff", radix: 16) == 255)
        #expect(BigInt("FF", radix: 16) == 255)
        #expect(BigInt("00000000000000000000001") == 1)
        // and the rejections
        #expect(BigInt("") == nil)
        #expect(BigInt("-") == nil)
        #expect(BigInt("12x") == nil)
        #expect(BigInt("2", radix: 2) == nil)
        #expect(BigUInt("-1") == nil, "an unsigned type must refuse a sign")
    }

    // MARK: - floating point

    @Test func doubleConversion() {
        #expect(Double(BigInt(0)) == 0)
        #expect(Double(BigInt(1)) == 1)
        #expect(Double(BigInt(-1)) == -1)
        for a in [1, -1, 3, -3, 1 << 52, 1 << 53, (1 << 53) + 1, Int.max, Int.min + 1] {
            // anything up to 2^53 is exact, and beyond it Double's own rounding
            // of the same integer is the answer
            #expect(Double(BigInt(a)) == Double(a), "Double(BigInt(\(a)))")
        }
        // 2^1024 is the first power of two a Double cannot hold
        #expect(Double(BigInt(1) << 1023) == 0x1p1023)
        #expect(Double(BigInt(1) << 1024).isInfinite)
        #expect(Double(BigInt(-1) << 1024) == -.infinity)
        // round half to even, exactly at the tie
        let tie = (BigInt(1) << 54) + 1           // 54 bits, tie broken by sticky
        #expect(Double(tie) == Double(1 << 54) + 2)
        #expect(Double(BigInt(1) << 54) == Double(1 << 54))
        // and back the other way
        #expect(BigInt(2.0) == 2)
        #expect(BigInt(-2.5) == -2)               // toward zero
        #expect(BigInt(exactly: 2.5) == nil)
        #expect(BigInt(exactly: 4.0) == 4)
        #expect(BigInt(exactly: Double.nan) == nil)
        #expect(BigInt(exactly: Double.infinity) == nil)
        #expect(BigUInt(exactly: -1.0) == nil)
        #expect(BigInt(0x1p200) == BigInt(1) << 200)
        #expect(Double(BigInt(0x1p200)) == 0x1p200)
    }

    // MARK: - Codable

    @Test func codableRoundTrip() throws {
        var rng = Random(seed: 99)
        var values = [BigInt(0), BigInt(1), BigInt(-1)]
        for _ in 0 ..< 20 { values.append(rng.big(limbs: 1 + Int(rng.next() % 4))) }
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        for v in values {
            let data = try encoder.encode(v)
            #expect(try decoder.decode(BigInt.self, from: data) == v, "BigInt \(v)")
            let udata = try encoder.encode(v.magnitude)
            #expect(try decoder.decode(BigUInt.self, from: udata) == v.magnitude, "BigUInt \(v)")
        }
        // BigRational's synthesized Codable rides on ours
        let q = BigRat(355, 113)
        #expect(try decoder.decode(BigRat.self, from: encoder.encode(q)) == q)
    }
}
