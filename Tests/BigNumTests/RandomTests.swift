import Testing
@testable import BigNum

///
/// `random(...)` on every type that has it.
///
/// Every distribution assertion here draws from a **seeded** generator, so a
/// failure is reproducible and a pass is not luck. A statistical test on system
/// randomness is a flaky test with extra steps.
///
@Suite struct RandomTests {

    /// SplitMix64 as a `RandomNumberGenerator`, so the library's own code paths
    /// are exercised with a sequence this file controls.
    struct Seeded : RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    // MARK: - widths

    @Test func maximumWidthStaysUnderTwoToTheWidth() {
        var g = Seeded(seed: 1)
        for width in [0, 1, 2, 7, 63, 64, 65, 127, 128, 129, 1000] {
            let ceiling = BigUInt(1) << width
            for _ in 0 ..< 200 {
                let v = BigUInt.random(withMaximumWidth: width, using: &g)
                #expect(v < ceiling, "\(v) should be under 2^\(width)")
                let s = BigInt.random(withMaximumWidth: width, using: &g)
                #expect(s >= 0 && s < BigInt(ceiling), "signed \(s) out of 0..<2^\(width)")
            }
        }
        #expect(BigUInt.random(withMaximumWidth: 0, using: &g) == 0, "no bits, no value")
        #expect(BigInt.random(withMaximumWidth: 0, using: &g) == 0)
    }

    @Test func exactWidthIsExact() {
        var g = Seeded(seed: 2)
        for width in [1, 2, 7, 63, 64, 65, 127, 128, 129, 521] {
            for _ in 0 ..< 100 {
                let v = BigUInt.random(withExactWidth: width, using: &g)
                #expect(v.bitWidth == width, "\(v) is \(v.bitWidth) bits, wanted \(width)")
                #expect(v >= BigUInt(1) << (width - 1), "top bit not set")
                #expect(v < BigUInt(1) << width)
                // BigInt's bitWidth counts a sign bit, so it is one more
                let s = BigInt.random(withExactWidth: width, using: &g)
                #expect(s.magnitude.bitWidth == width, "signed magnitude width")
                #expect(s > 0)
            }
        }
        #expect(BigUInt.random(withExactWidth: 0, using: &g) == 0, "zero is the only 0-bit value")
    }

    // MARK: - bounds

    @Test func lessThanStaysBelowTheLimit() {
        var g = Seeded(seed: 3)
        for limit in [1, 2, 3, 5, 6, 7, 8, 9, 100, 255, 256, 257] {
            for _ in 0 ..< 200 {
                let v = BigUInt.random(lessThan: BigUInt(limit), using: &g)
                #expect(v < BigUInt(limit), "\(v) should be under \(limit)")
                let s = BigInt.random(lessThan: BigInt(limit), using: &g)
                #expect(s >= 0 && s < BigInt(limit))
            }
        }
        // and a limit far beyond a word
        let big = (BigUInt(1) << 300) + 12345
        for _ in 0 ..< 100 {
            #expect(BigUInt.random(lessThan: big, using: &g) < big)
        }
        #expect(BigUInt.random(lessThan: 1, using: &g) == 0, "only zero is under one")
    }

    /// The range form is **closed** — `to:` is reachable. That is the whole point
    /// of the spelling, so it is worth a test that would fail if it were
    /// half-open.
    @Test func rangeIncludesBothEnds() {
        var g = Seeded(seed: 4)
        var sawLower = false, sawUpper = false
        for _ in 0 ..< 2000 {
            let v = BigInt.random(from: -3, to: 3, using: &g)
            #expect(v >= -3 && v <= 3, "\(v) outside -3...3")
            if v == -3 { sawLower = true }
            if v == 3 { sawUpper = true }
        }
        #expect(sawLower, "the lower bound must be reachable")
        #expect(sawUpper, "the UPPER bound must be reachable -- the range is closed")
        // a single-value range returns that value rather than diverging
        #expect(BigInt.random(from: 7, to: 7, using: &g) == 7)
        #expect(BigUInt.random(from: 7, to: 7, using: &g) == 7)
        // BigUInt has its own overload, so it needs its own proof that `to:` is
        // included -- a mutation to the signed one alone would otherwise pass here
        var sawULower = false, sawUUpper = false
        for _ in 0 ..< 2000 {
            let v = BigUInt.random(from: 10, to: 14, using: &g)
            #expect(v >= 10 && v <= 14, "\(v) outside 10...14")
            if v == 10 { sawULower = true }
            if v == 14 { sawUUpper = true }
        }
        #expect(sawULower && sawUUpper, "BigUInt's range must include both ends")
        // spanning zero, and wholly negative
        for _ in 0 ..< 500 {
            let v = BigInt.random(from: -100, to: -50, using: &g)
            #expect(v >= -100 && v <= -50, "\(v) outside -100...-50")
        }
        // and a span wider than a word
        let lo = -(BigInt(1) << 200), hi = BigInt(1) << 200
        for _ in 0 ..< 200 {
            let v = BigInt.random(from: lo, to: hi, using: &g)
            #expect(v >= lo && v <= hi)
        }
    }

    // MARK: - uniformity
    //
    // The interesting failure is not "out of range" but "biased", which is what
    // scaling a draw with `%` would give. A limit of 5 needs three bits, so a
    // modulo implementation would map 0...7 onto 0...4 and hand 0, 1 and 2 twice
    // the share of 3 and 4. Rejection gives them all a fifth. With a fixed seed
    // this is a deterministic assertion, not a coin flip.

    @Test func drawsAreUnbiasedAcrossAPowerOfTwoBoundary() {
        var g = Seeded(seed: 5)
        let draws = 100_000
        for limit in [3, 5, 6, 7, 9] {
            var counts = [Int](repeating: 0, count: limit)
            for _ in 0 ..< draws {
                counts[Int(BigUInt.random(lessThan: BigUInt(limit), using: &g))] += 1
            }
            let expected = Double(draws) / Double(limit)
            for (value, count) in counts.enumerated() {
                let ratio = Double(count) / expected
                #expect(0.94 < ratio && ratio < 1.06,
                        "limit \(limit): value \(value) came up \(count) times, expected ~\(Int(expected))")
            }
            // the specific shape a modulo bug would leave: the low values
            // overrepresented by about 2x relative to the high ones
            let low = counts[0], high = counts[limit - 1]
            #expect(Double(low) / Double(high) < 1.15,
                    "limit \(limit): 0 appeared \(low) times against \(high) for \(limit - 1) — that is modulo bias")
        }
    }

    @Test func rangeDrawsAreUnbiased() {
        var g = Seeded(seed: 6)
        let draws = 60_000
        var counts = [Int](repeating: 0, count: 5)          // -2 ... 2, five values
        for _ in 0 ..< draws {
            counts[Int(BigInt.random(from: -2, to: 2, using: &g)) + 2] += 1
        }
        let expected = Double(draws) / 5
        for (i, count) in counts.enumerated() {
            let ratio = Double(count) / expected
            #expect(0.94 < ratio && ratio < 1.06,
                    "value \(i - 2) came up \(count) times, expected ~\(Int(expected))")
        }
    }

    @Test func widthDrawsFillTheirBits() {
        // Every bit position under the width should be set sometimes and clear
        // sometimes; a masking mistake shows up as a bit that never moves.
        var g = Seeded(seed: 7)
        let width = 128
        var everSet = [Bool](repeating: false, count: width)
        var everClear = [Bool](repeating: false, count: width)
        for _ in 0 ..< 400 {
            let v = BigUInt.random(withMaximumWidth: width, using: &g)
            for bit in 0 ..< width {
                if (v >> bit) & 1 == 1 { everSet[bit] = true } else { everClear[bit] = true }
            }
        }
        #expect(!everSet.contains(false), "some bit was never set")
        #expect(!everClear.contains(false), "some bit was never clear")
    }

    // MARK: - determinism

    @Test func aSeededGeneratorRepeats() {
        var a = Seeded(seed: 42), b = Seeded(seed: 42)
        for _ in 0 ..< 50 {
            #expect(BigUInt.random(withMaximumWidth: 256, using: &a)
                      == BigUInt.random(withMaximumWidth: 256, using: &b))
            #expect(BigInt.random(from: -1000, to: 1000, using: &a)
                      == BigInt.random(from: -1000, to: 1000, using: &b))
            #expect(Int.random(lessThan: 1000, using: &a) == Int.random(lessThan: 1000, using: &b))
        }
        var c = Seeded(seed: 43)
        var differs = false
        var d = Seeded(seed: 42)
        for _ in 0 ..< 20 where !differs {
            if BigUInt.random(withMaximumWidth: 256, using: &c)
                 != BigUInt.random(withMaximumWidth: 256, using: &d) { differs = true }
        }
        #expect(differs, "a different seed should give a different sequence")
    }

    /// The unseeded entry points use the system generator; all that can be
    /// asserted is that they stay in range and are not constant.
    @Test func theUnseededFormsWork() {
        var seen = Set<String>()
        for _ in 0 ..< 50 {
            let v = BigUInt.random(withMaximumWidth: 128)
            #expect(v < BigUInt(1) << 128)
            seen.insert(v.description)
            #expect(BigUInt.random(withExactWidth: 64).bitWidth == 64)
            #expect(BigUInt.random(lessThan: 1000) < 1000)
            let r = BigInt.random(from: -5, to: 5)
            #expect(r >= -5 && r <= 5)
            let i = Int.random(from: -5, to: 5)
            #expect(i >= -5 && i <= 5)
        }
        #expect(seen.count > 45, "128-bit draws should essentially never repeat")
    }

    // MARK: - the built-in integers

    @Test func fixedWidthTypesGetItToo() {
        var g = Seeded(seed: 8)
        for _ in 0 ..< 500 {
            let i = Int.random(from: -100, to: 100, using: &g)
            #expect(i >= -100 && i <= 100)
            let u = UInt.random(lessThan: 1000, using: &g)
            #expect(u < 1000)
            let b = UInt8.random(from: 10, to: 20, using: &g)
            #expect(b >= 10 && b <= 20)
            let s = Int8.random(from: -128, to: 127, using: &g)
            #expect(s >= -128 && s <= 127)
            #expect(UInt8.random(withMaximumWidth: 8, using: &g) <= UInt8.max)
            #expect(UInt64.random(withExactWidth: 64, using: &g) >= UInt64(1) << 63)
            #expect(Int32.random(withExactWidth: 31, using: &g) >= Int32(1) << 30)
            #expect(UInt16.random(lessThan: 1, using: &g) == 0)
        }
        // the full range of a narrow type, both ends reachable
        var sawMin = false, sawMax = false
        for _ in 0 ..< 4000 {
            let v = Int8.random(from: Int8.min, to: Int8.max, using: &g)
            if v == Int8.min { sawMin = true }
            if v == Int8.max { sawMax = true }
        }
        #expect(sawMin && sawMax, "Int8.min and Int8.max must both be reachable")
        // and at the very top of the widest unsigned type
        var sawTop = false
        for _ in 0 ..< 2000 {
            if UInt64.random(from: UInt64.max - 2, to: UInt64.max, using: &g) == UInt64.max { sawTop = true }
        }
        #expect(sawTop, "UInt64.max must be reachable")
    }

    /// Every width form can ask for more than the type holds, and then it traps
    /// like any other conversion here. A trap cannot be `#expect`ed, so what is
    /// checked is the boundary either side of it.
    @Test func widthsAtTheEdgeOfEachType() {
        var g = Seeded(seed: 9)
        #expect(Int8.random(withMaximumWidth: 7, using: &g) >= 0)      // fits
        #expect(UInt8.random(withMaximumWidth: 8, using: &g) >= 0)     // fits
        #expect(Int64.random(withExactWidth: 63, using: &g) > 0)       // fits
        #expect(UInt64.random(withExactWidth: 64, using: &g) > 0)      // fits
        // Int8.random(withMaximumWidth: 8) would trap: 8 bits needs the sign bit.
        // UInt8.random(withMaximumWidth: 9) likewise.
    }
}
