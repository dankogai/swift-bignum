import Testing
import Foundation   // Dispatch, for concurrentPerform
@testable import BigNum

///
/// Concurrent use of the constants and of everything that reaches for them.
///
/// There is nothing to synchronise any more: the constants are literals, refined on
/// demand and never cached, so no two threads share a byte of mutable state. This
/// suite is what makes that a tested claim rather than a design intention — if
/// someone reintroduces a cache, or the refinement above the seed acquires state,
/// these fail with wrong values rather than crashing once a fortnight on CI.
///
/// The history is worth keeping: the constants used to be memoised in `static var`s,
/// two threads filling one could corrupt a refcount, and the symptom was a single
/// flaky Linux CI abort that took a sanitiser run to pin down.
///
@Suite struct ConcurrencyTests {

    /// Computed serially first, so the concurrent runs have something to be
    /// compared against that is not itself concurrent.
    static let expected: [Int: [String]] = {
        var table: [Int: [String]] = [:]
        for px in [64, 128, 192, 256, 320] {
            table[px] = [BigRat.E(precision: px).toString(),
                         BigRat.LN2(precision: px).toString(),
                         BigRat.LN10(precision: px).toString(),
                         BigRat.ATAN1(precision: px).toString(),
                         BigRat.SQRT2(precision: px).toString()]
        }
        return table
    }()

    @Test func constantsAgreeAcrossThreads() {
        let precisions = [64, 128, 192, 256, 320]
        let wrong = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        wrong.initialize(to: 0)
        defer { wrong.deallocate() }
        DispatchQueue.concurrentPerform(iterations: 64) { i in
            for k in 0 ..< 12 {
                let px = precisions[(i + k) % precisions.count]
                let got = [BigRat.E(precision: px).toString(),
                           BigRat.LN2(precision: px).toString(),
                           BigRat.LN10(precision: px).toString(),
                           BigRat.ATAN1(precision: px).toString(),
                           BigRat.SQRT2(precision: px).toString()]
                if got != Self.expected[px]! { OSAtomicIncrement32(wrong) }
            }
        }
        #expect(wrong.pointee == 0, "\(wrong.pointee) concurrent constant reads disagreed with the serial value")
    }

    /// The same, across both types at once — `BigFloat.E` delegates to `BigRat.E`,
    /// so this is the path where one constant's computation asks for another's
    /// while other threads are doing the same.
    @Test func bothTypesAtOnce() {
        let serialFloat = BigFloat.exp(1).description
        let serialRat = BigRat.exp(1).toString()
        let mismatches = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        mismatches.initialize(to: 0)
        defer { mismatches.deallocate() }
        DispatchQueue.concurrentPerform(iterations: 48) { i in
            for _ in 0 ..< 10 {
                if i & 1 == 0 {
                    if BigFloat.exp(1).description != serialFloat { OSAtomicIncrement32(mismatches) }
                } else {
                    if BigRat.exp(1).toString() != serialRat { OSAtomicIncrement32(mismatches) }
                }
            }
        }
        #expect(mismatches.pointee == 0, "\(mismatches.pointee) results differed under concurrency")
    }

    /// Transcendentals that reach for a constant on the way, hammered together.
    @Test func transcendentalsUnderContention() {
        let want = [BigRat.sqrt(2).toString(), BigRat.log(2).toString(),
                    BigRat.exp(1).toString(), BigRat.pi.toString(),
                    BigRat.atan2(y: 1, x: 1).toString(),
                    BigRat.pow(2, BigRat(1, 2)).toString()]
        let bad = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        bad.initialize(to: 0)
        defer { bad.deallocate() }
        DispatchQueue.concurrentPerform(iterations: 40) { _ in
            let got = [BigRat.sqrt(2).toString(), BigRat.log(2).toString(),
                       BigRat.exp(1).toString(), BigRat.pi.toString(),
                       BigRat.atan2(y: 1, x: 1).toString(),
                       BigRat.pow(2, BigRat(1, 2)).toString()]
            if got != want { OSAtomicIncrement32(bad) }
        }
        #expect(bad.pointee == 0, "\(bad.pointee) transcendental results differed under concurrency")
    }

    /// Integer work never had shared state. Worth a test anyway, since "by
    /// construction" is a claim about the code as it stands today.
    @Test func integerWorkIsIndependent() {
        let m = (BigInt(1) << 127) - 1
        let expected = BigInt(3).power(m - 1, mod: m).description
        let bad = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        bad.initialize(to: 0)
        defer { bad.deallocate() }
        DispatchQueue.concurrentPerform(iterations: 32) { i in
            if BigInt(3).power(m - 1, mod: m).description != expected { OSAtomicIncrement32(bad) }
            if (BigInt(1) << (100 + i)).squareRoot() != BigInt(1) << ((100 + i) / 2) {
                if (100 + i) % 2 == 0 { OSAtomicIncrement32(bad) }   // exact only for even powers
            }
            if !BigInt(1000003).isPrime! { OSAtomicIncrement32(bad) }
            if BigUInt("deadbeef", radix: 16)! != 3735928559 { OSAtomicIncrement32(bad) }
        }
        #expect(bad.pointee == 0, "\(bad.pointee) integer results differed under concurrency")
    }
}

///
/// The constants themselves: the seed, its boundary, and the refinement above it.
///
/// Worth its own suite because the seed answers everything the rest of the test
/// suite asks for — the default precision is 128 — so the code above 512 bits was
/// exercised by nothing. Transcribing π/4's series into Constants.swift I dropped
/// the alternating sign, and every test still passed. These are the tests that
/// would have caught it.
///
@Suite struct ConstantTests {

    /// Enough digits of each to check well past the seed. π/4 comes from the
    /// published expansion of π; the others are checkable against identities below.
    static let piOver4 = "0.785398163397448309615660845819875721049292349843776455243736148076954101571552249657008706335529266995537021628320576661773461152387645557931339852032120279362571025675484630276389911155737238732595491107202743916483361532118912058446695791317800477286412141730865087152613581662053348401815062285318"

    @Test func belowTheSeedIsTheSeed() {
        // The seed is a literal, so these are exact truncations and must not move
        // between calls, in either order, at any precision.
        for px in [1, 2, 8, 64, 128, 256, 511, 512] {
            let a = BigRat.ATAN1(precision: px).toString()
            let b = BigRat.ATAN1(precision: px).toString()
            #expect(a == b, "π/4 at \(px) bits changed between two calls")
            #expect(Self.piOver4.hasPrefix(String(a.dropFirst().prefix(px / 4))),
                    "π/4 at \(px) bits disagrees with the published expansion: \(a)")
        }
        // and asking wide first must not change what a narrow request returns
        let narrowFirst = BigRat.SQRT2(precision: 64).toString()
        _ = BigRat.SQRT2(precision: 1024)
        #expect(BigRat.SQRT2(precision: 64).toString() == narrowFirst,
                "a wide request changed what a narrow one returns")
    }

    /// Above the seed each constant is computed, and √2 by refining the seed.
    /// Checked against the identity each satisfies, since that needs no table.
    @Test func aboveTheSeedIsStillCorrect() {
        for px in [513, 640, 768] {
            // √2 · √2 == 2, to the precision asked for
            let r2 = BigRat.SQRT2(precision: px)
            let err = (r2 * r2 - 2).magnitude
            #expect(err < BigRat.getEpsilon(precision: px - 4),
                    "√2 at \(px) bits squares to 2 ± \(err)")
            // ln 2 and ln 10: exp of them is 2 and 10
            // exp and log are expensive at these widths, so check the identity at
            // the boundary only -- the point is that the path runs and is right,
            // not to re-test exp at four precisions
            if px == 513 {
                #expect((BigRat.exp(BigRat.LN2(precision: px), precision: px) - 2).magnitude
                          < BigRat.getEpsilon(precision: px - 12), "exp(ln 2) at \(px)")
                #expect((BigRat.log(BigRat.E(precision: px), precision: px) - 1).magnitude
                          < BigRat.getEpsilon(precision: px - 12), "log(e) at \(px)")
            }
            // π/4 against the published digits -- this is the one that caught the
            // dropped sign, and an identity would not have
            let a = BigRat.ATAN1(precision: px).toString()
            #expect(Self.piOver4.hasPrefix(String(a.dropFirst().prefix(140))),
                    "π/4 at \(px) bits disagrees with the published expansion:\n      \(a)")
        }
    }

    /// The refinement must actually refine: crossing the boundary should not make
    /// the answer worse than just below it.
    @Test func theBoundaryIsContinuous() {
        let below = BigRat.SQRT2(precision: 512)
        let above = BigRat.SQRT2(precision: 513)
        #expect((below - above).magnitude < BigRat.getEpsilon(precision: 500),
                "√2 jumps across the seed boundary")
        for px in [512, 513, 600] {
            let v = BigRat.SQRT2(precision: px)
            #expect((v * v - 2).magnitude < BigRat.getEpsilon(precision: px - 4),
                    "√2 at \(px) bits does not square to 2")
        }
    }
}
