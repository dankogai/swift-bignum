import Testing
import Foundation   // Dispatch, for concurrentPerform
@testable import BigNum

///
/// Concurrent use of the memoised constants.
///
/// These are the only mutable globals in the package, and until they were guarded
/// two threads populating one at the same time could corrupt a refcount — a
/// crashed process rather than a wrong number. It surfaced as a single flaky Linux
/// CI failure and needed a stress test under the thread sanitiser to pin down.
///
/// A test cannot reliably provoke a data race, so this is not the proof that the
/// lock works; the sanitiser is, run against the code with and without it. What
/// this suite does is cheaper and still worth having: it drives every constant
/// from many threads at many precisions and insists every thread comes back with
/// the right answer, so a regression that serialised badly, cached the wrong
/// precision, or published a half-built value would show up as a wrong result
/// rather than as luck.
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
    /// Nothing here should be able to see a partially published memo.
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

    /// Integer work has no shared state at all — no memo, no configuration — so it
    /// is safe by construction. Worth a test anyway, since "by construction" is a
    /// claim about the code as it stands today.
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
