import Testing
import Foundation
import Dispatch     // concurrentPerform; on Linux this is not re-exported by Foundation
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

    /// Runs `body` on `count` workers and returns how many times it reported a
    /// mismatch.
    ///
    /// Each worker writes only its own slot, so there is nothing shared to
    /// synchronise and no atomic to reach for -- which matters because the obvious
    /// atomic, `OSAtomicIncrement32`, is Darwin-only and this package builds on
    /// Linux too.  That is exactly how the first version of this file broke CI.
    static func tally(_ count: Int, _ body: (Int) -> Int) -> Int {
        let slots = UnsafeMutableBufferPointer<Int>.allocate(capacity: count)
        defer { slots.deallocate() }
        slots.initialize(repeating: 0)
        let base = slots.baseAddress!
        DispatchQueue.concurrentPerform(iterations: count) { i in
            base[i] = body(i)
        }
        return slots.reduce(0, +)
    }

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
        let wrong = Self.tally(64) { i in
            var bad = 0
            for k in 0 ..< 12 {
                let px = precisions[(i + k) % precisions.count]
                let got = [BigRat.E(precision: px).toString(),
                           BigRat.LN2(precision: px).toString(),
                           BigRat.LN10(precision: px).toString(),
                           BigRat.ATAN1(precision: px).toString(),
                           BigRat.SQRT2(precision: px).toString()]
                if got != Self.expected[px]! { bad += 1 }
            }
            return bad
        }
        #expect(wrong == 0, "\(wrong) concurrent constant reads disagreed with the serial value")
    }

    /// The same, across both types at once — `BigFloat.E` delegates to `BigRat.E`,
    /// so this is the path where one constant's computation asks for another's
    /// while other threads are doing the same.
    @Test func bothTypesAtOnce() {
        let serialFloat = BigFloat.exp(1).description
        let serialRat = BigRat.exp(1).toString()
        let mismatches = Self.tally(48) { i in
            var bad = 0
            for _ in 0 ..< 10 {
                if i & 1 == 0 {
                    if BigFloat.exp(1).description != serialFloat { bad += 1 }
                } else {
                    if BigRat.exp(1).toString() != serialRat { bad += 1 }
                }
            }
            return bad
        }
        #expect(mismatches == 0, "\(mismatches) results differed under concurrency")
    }

    /// Transcendentals that reach for a constant on the way, hammered together.
    @Test func transcendentalsUnderContention() {
        let want = [BigRat.sqrt(2).toString(), BigRat.log(2).toString(),
                    BigRat.exp(1).toString(), BigRat.pi.toString(),
                    BigRat.atan2(y: 1, x: 1).toString(),
                    BigRat.pow(2, BigRat(1, 2)).toString()]
        let bad = Self.tally(40) { _ in
            let got = [BigRat.sqrt(2).toString(), BigRat.log(2).toString(),
                       BigRat.exp(1).toString(), BigRat.pi.toString(),
                       BigRat.atan2(y: 1, x: 1).toString(),
                       BigRat.pow(2, BigRat(1, 2)).toString()]
            return got == want ? 0 : 1
        }
        #expect(bad == 0, "\(bad) transcendental results differed under concurrency")
    }

    /// Integer work never had shared state. Worth a test anyway, since "by
    /// construction" is a claim about the code as it stands today.
    @Test func integerWorkIsIndependent() {
        let m = (BigInt(1) << 127) - 1
        let expected = BigInt(3).power(m - 1, mod: m).description
        let bad = Self.tally(32) { i in
            var n = 0
            if BigInt(3).power(m - 1, mod: m).description != expected { n += 1 }
            // 2^k has an exact integer square root only for even k
            if (100 + i) % 2 == 0 && (BigInt(1) << (100 + i)).squareRoot() != BigInt(1) << ((100 + i) / 2) { n += 1 }
            if BigInt(1000003).isPrime != true { n += 1 }
            if BigUInt("deadbeef", radix: 16)! != 3735928559 { n += 1 }
            return n
        }
        #expect(bad == 0, "\(bad) integer results differed under concurrency")
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

    /// π/4 to 650 digits, enough to check every precision this suite asks for.
    ///
    /// Generated, not pasted. The first version of this constant was 503 digits of a
    /// string I had typed, and comparing against it made a correct 2048-bit result
    /// look 113 digits short — the reference ran out, not the library.
    static let piOver4 = "0.78539816339744830961566084581987572104929234984377645524373614807695410157155224965700870633552926699553702162832057666177346115238764555793133985203212027936257102567548463027638991115573723873259549110720274391648336153211891205844669579131780047728641214173086508715261358166205334840181506228531843114675165157889704372038023024070731352292884109197314759000283263263720511663034603673798537790235826431759143989798827304652934548315294827627963701861559499068739183797143818122280698454575298728245841834061016416077150534873659880618429767554496523592569263480429407329418809616870461691735128300014203178631589020694644283568944740229340929468"

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
        for px in [513, 640, 768, 2048] {
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
            // Compare as many digits as the precision actually carries, less a
            // couple for the last-bit rounding -- the point is to catch a wrong
            // series, and a fixed 140 digits would have passed a value that went
            // wrong at 200.
            let digits = Int(Double(px) * 0.30103) - 2
            #expect(Self.piOver4.hasPrefix(String(a.dropFirst().prefix(digits))),
                    "π/4 at \(px) bits disagrees with π/4 in its first \(digits) digits:\n      \(a)")
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
