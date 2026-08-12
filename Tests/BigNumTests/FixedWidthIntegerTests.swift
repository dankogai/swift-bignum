import Testing
@testable import BigNum

///
/// The built-in integers, now that they carry BigNum's number theory.  Every one
/// of these operations is defined as "do it in `BigInt` and come back", so
/// `BigInt` is the oracle: what is tested here is the round trip, not the
/// arithmetic, which `BigIntTests` and `PrimalityTests` already pin down.
///
/// Hand-written expected values are deliberately rare below.  Twice while writing
/// this I typed a modular power from memory and was wrong both times, so the
/// constants that remain came from Python's `pow` and everything else is
/// differential.
///
@Suite struct FixedWidthIntegerTests {

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
    }

    // MARK: - power

    @Test func powerAgainstBigInt() {
        var rng = Random(seed: 0xC0FFEE)
        for _ in 0 ..< 400 {
            let base = Int(truncatingIfNeeded: rng.next()) % 1000
            let e = Int(rng.next() % 8)
            let wide = BigInt(base).power(e)
            // only compare where the answer is representable -- where it is not,
            // the fixed-width form is documented to trap, which is checked below
            guard let want = Int(exactly: wide) else { continue }
            #expect(base.power(e) == want, "\(base)^\(e)")
            if base >= 0, let uwant = UInt(exactly: wide) {
                #expect(UInt(base).power(e) == uwant, "unsigned \(base)^\(e)")
            }
            if let small = Int8(exactly: wide), let b8 = Int8(exactly: base) {
                #expect(b8.power(e) == small, "Int8 \(base)^\(e)")
            }
        }
        // the edges of what each width can hold
        #expect(Int(2).power(62) == 4611686018427387904)
        #expect(UInt(2).power(63) == 9223372036854775808)
        #expect(Int8(11).power(2) == 121)
        #expect(UInt8(15).power(2) == 225)
        #expect(Int(-2).power(3) == -8 && Int(-2).power(4) == 16)
        #expect(Int(5).power(0) == 1 && Int(5).power(1) == 5)
        #expect(Int(5).power(-2) == 0, "no integral reciprocal, as for BigInt")
        #expect(Int(1).power(-9) == 1 && Int(-1).power(-9) == -1)
    }

    /// The exponent is generic over `SignedInteger` rather than an `Int`, so any
    /// *signed* integer type can be written in that position.  Only the first line
    /// of each group below compiled when it was an `Int`.
    ///
    /// Signed and not merely `BinaryInteger`, because a negative exponent is part
    /// of what `power` means -- the reciprocal, which is 0 for `power(_:)` and the
    /// modular inverse for `power(_:mod:)`.  An unsigned exponent type cannot
    /// express the argument the documented behaviour is about, so it is rejected at
    /// compile time rather than silently made unreachable.
    ///
    /// This is a compile-time claim as much as a runtime one: every line here is a
    /// distinct overload resolution, and the test earns its keep by failing to
    /// build if one of them stops resolving.
    @Test func anySignedIntegerTypeCanBeAnExponent() {
        // a fixed-width receiver
        #expect(Int(2).power(10) == 1024)
        #expect(Int(2).power(Int8(10)) == 1024)
        #expect(Int(2).power(Int32(10)) == 1024)
        #expect(Int(2).power(BigInt(10)) == 1024)
        // the receiver may still be unsigned; it is the exponent that may not be
        #expect(UInt8(3).power(Int8(4)) == 81)
        #expect(UInt(2).power(BigInt(63)) == 9223372036854775808)
        // a big receiver
        #expect(BigInt(2).power(10) == 1024)
        #expect(BigInt(2).power(Int8(10)) == 1024)
        #expect(BigInt(2).power(BigInt(10)) == 1024)
        #expect(BigUInt(2).power(Int64(10)) == 1024)
        // the sign rules do not change with the exponent's type
        #expect(BigInt(-2).power(Int8(3)) == -8)
        #expect(BigInt(5).power(Int8(-2)) == 0)
        #expect(BigInt(-1).power(Int16(-3)) == -1)
        #expect(Int(-2).power(Int8(3)) == -8)
        // and neither do the modular ones
        #expect(BigInt(3).power(Int8(5), mod: BigInt(7)) == 5)
        #expect(BigInt(3).power(BigInt(5), mod: BigInt(7)) == 5)
        #expect(BigInt(2).power(Int8(-1), mod: 5) == 3)
        #expect(Int(2).power(Int16(1024), mod: 1_000_000_007) == 812734592)
        // The one place an unsigned exponent still resolves: `power(_ exponent:
        // Self, mod:)` is concrete, so an unsigned receiver reaches it with its own
        // type.  That is the cryptographic case, and it keeps working.
        #expect(BigUInt(3).power(BigUInt(1) << 100, mod: 1000000007) == 870513414)
        // An exponent past `UInt` is meaningful only with a modulus to bound the
        // answer, and `power(_:)` rejects one.  A trap cannot be `#expect`ed, so
        // what is checked here is the boundary it has to *accept* -- if the guard
        // were off by one this would trap rather than fail.
        #expect(BigInt(1).power(BigInt(UInt.max)) == 1)
    }

    /// The modular form is the one that cannot overflow, since the answer is
    /// bounded by a modulus that is a `Self` already.  It is therefore also the
    /// one worth checking at full width.
    @Test func powerModNeverOverflowsAndMatchesBigInt() {
        var rng = Random(seed: 0xBEEF)
        for _ in 0 ..< 500 {
            let base = Int(truncatingIfNeeded: rng.next())
            let m = Int(truncatingIfNeeded: rng.next())
            if m == 0 { continue }
            let e = Int(rng.next() % 64)
            let want = BigInt(base).power(e, mod: BigInt(m))
            #expect(base.power(e, mod: m) == Int(want), "\(base)^\(e) mod \(m)")
        }
        // narrow types, where the naive `a * b % m` would overflow immediately
        for _ in 0 ..< 300 {
            let base = UInt8(truncatingIfNeeded: rng.next())
            let m = UInt8(truncatingIfNeeded: rng.next())
            if m == 0 { continue }
            let e = Int(rng.next() % 200)
            let want = BigInt(base).power(e, mod: BigInt(m))
            #expect(base.power(e, mod: m) == UInt8(want), "UInt8 \(base)^\(e) mod \(m)")
        }
        // at the very top of the range, where a product is two words wide
        #expect(UInt64.max.power(3, mod: UInt64.max - 2) == 8)
        #expect((Int.max - 1).power(Int.max - 2, mod: Int.max)
                  == Int(BigInt(Int.max - 1).power(BigInt(Int.max - 2), mod: BigInt(Int.max))))
        // Python's pow, for the values the documentation quotes
        #expect(Int(2).power(1024, mod: 1_000_000_007) == 812734592)
        #expect(Int(2).power(10, mod: 1000) == 24)
        #expect(UInt8(200).power(200, mod: 251) == 1)
        // and the conventions carry over from BigInt unchanged
        #expect(Int(-2).power(3, mod: 5) == 2, "the sign of the modulus")
        #expect(Int(2).power(3, mod: -5) == -2, "a negative modulus")
        #expect(Int(2).power(-1, mod: 5) == 3, "a negative exponent is the inverse")
        #expect(Int(5).power(3, mod: 1) == 0)
        // the exponent is generic over the signed integers, so all of these have to
        // compile and agree.  `UInt8(20)` was here and no longer compiles: the
        // exponent is `SignedInteger` now, since a negative one is half of what
        // `power(_:mod:)` is documented to do.
        #expect(Int(3).power(20, mod: 1_000_003) == 773943)
        #expect(Int(3).power(Int(20), mod: 1_000_003) == 773943)
        #expect(Int(3).power(Int8(20), mod: 1_000_003) == 773943)
        #expect(Int(3).power(BigInt(20), mod: 1_000_003) == 773943)
    }

    // MARK: - roots and divisors

    /// `squareRoot()` and `greatestCommonDivisor(with:)` reached the *signed*
    /// built-ins long ago through `RationalElement`; only the unsigned ones are
    /// new.  Both are checked here, since the point is that every built-in width
    /// now has them and gives the same answer.
    @Test func rootsAndDivisorsAgainstBigInt() {
        var rng = Random(seed: 0x5EED)
        for _ in 0 ..< 500 {
            let a = Int(truncatingIfNeeded: rng.next())
            let b = Int(truncatingIfNeeded: rng.next())
            let ua = UInt(bitPattern: a), ub = UInt(bitPattern: b)
            #expect(ua.squareRoot() == UInt(BigInt(ua).squareRoot()), "√\(ua)")
            if a >= 0 { #expect(a.squareRoot() == Int(BigInt(a).squareRoot()), "√\(a)") }
            #expect(ua.greatestCommonDivisor(with: ub)
                      == UInt(BigInt(ua).greatestCommonDivisor(with: BigInt(ub))),
                    "gcd(\(ua), \(ub))")
            // the signed one traps only for gcd(Int.min, Int.min), avoided here
            if a != Int.min || b != Int.min {
                #expect(a.greatestCommonDivisor(with: b)
                          == Int(BigInt(a).greatestCommonDivisor(with: BigInt(b))),
                        "gcd(\(a), \(b))")
            }
        }
        #expect(UInt8(255).squareRoot() == 15 && UInt8(256 - 1).squareRoot() == 15)
        #expect(UInt(4611686018427387904).squareRoot() == 2147483648)
        #expect(UInt(0).squareRoot() == 0 && UInt(1).squareRoot() == 1)
        #expect(UInt(1071).greatestCommonDivisor(with: 462) == 21)
        #expect(UInt8(48).greatestCommonDivisor(with: 18) == 6)
        #expect(UInt(0).greatestCommonDivisor(with: 5) == 5)
        #expect(Int(-12).greatestCommonDivisor(with: 18) == 6, "pre-existing, still right")
    }

    // MARK: - primality

    @Test func primalityMatchesBigInt() {
        for n in 0 ..< 2000 {
            let wide = BigInt(n)
            #expect(n.isPrime == wide.isPrime, "isPrime of \(n)")
            #expect(n.isProbablePrime == wide.isProbablePrime, "isProbablePrime of \(n)")
            #expect(n.isSurelyPrime == wide.isSurelyPrime, "isSurelyPrime of \(n)")
            #expect(UInt(n).isPrime == wide.isPrime, "unsigned isPrime of \(n)")
            #expect((-n).isPrime == BigInt(-n).isPrime, "isPrime of -\(n)")
            if n >= 3 && n & 1 == 1 {
                #expect(n.isLucasProbablePrime == wide.isLucasProbablePrime, "Lucas of \(n)")
                #expect(n.millerRabinTest(base: 2) == wide.millerRabinTest(base: 2), "MR of \(n)")
            }
            #expect(n.isMersennePrime == wide.isMersennePrime, "isMersennePrime of \(n)")
            for a in [-7, -1, 0, 1, 2, 3, 5] {
                #expect(n.jacobiSymbol(a) == wide.jacobiSymbol(a), "jacobi(\(a)/\(n))")
            }
        }
        // the narrow widths, exhaustively -- every value a UInt8 can hold
        for n in UInt8.min ... UInt8.max {
            #expect(n.isPrime == BigInt(n).isPrime, "UInt8 \(n)")
        }
        for n in Int8.min ... Int8.max {
            #expect(n.isPrime == BigInt(n).isPrime, "Int8 \(n)")
        }
        // and the top of the 64-bit range
        #expect(UInt64.max.isPrime! == false)
        #expect(Int.max.isPrime! == false)
        #expect(Int.min.isPrime! == false)
        #expect(UInt64(18446744073709551557).isPrime! == true, "the last prime below 2^64")
        #expect(Int(9223372036854775783).isPrime! == true, "the last prime below 2^63")
    }

    /// The guarantee that makes `isPrime!` safe on the built-ins: no type of 64
    /// bits or fewer can hold a value outside the exhaustively verified range.
    /// The force unwraps *are* the assertions -- they trap if that ever breaks.
    @Test func isPrimeIsNeverNilForTheBuiltins() {
        for n in 0 ..< 1000 {
            #expect(n.isPrime != nil)
            #expect(UInt(n).isPrime != nil)
            #expect((-n).isPrime! == false)
        }
        var primesNearTheTop = 0
        for offset in 0 ... 80 {
            let n = UInt64.max - UInt64(offset)
            #expect(n.isPrime != nil, "\(n)")
            if n.isPrime == true { primesNearTheTop += 1 }
            #expect((Int.max - offset).isPrime != nil, "\(Int.max - offset)")
            #expect((Int.min + offset).isPrime! == false, "negatives are settled")
        }
        #expect(primesNearTheTop > 0, "the window must hold a prime to be testing anything")
        for n in UInt8.min ... UInt8.max { #expect(n.isPrime != nil, "UInt8 \(n)") }
        for n in Int16.min ... Int16.min + 200 { #expect(n.isPrime != nil, "Int16 \(n)") }
    }

    @Test func walkingThePrimes() {
        for n in 0 ..< 500 {
            #expect(n.nextPrime == Int(BigInt(n).nextPrime), "nextPrime of \(n)")
            #expect(n.prevPrime.map { BigInt($0) } == BigInt(n).prevPrime, "prevPrime of \(n)")
            #expect(UInt(n).nextPrime == UInt(BigInt(n).nextPrime), "unsigned nextPrime of \(n)")
        }
        #expect(Int(1000).nextPrime == 1009 && Int(1000).prevPrime == 997)
        #expect(Int(2).prevPrime == nil && UInt(2).prevPrime == nil && Int(-5).prevPrime == nil)
        #expect(Int(0).nextPrime == 2 && Int(-5).nextPrime == 2 && UInt(0).nextPrime == 2)
        #expect(UInt8(200).nextPrime == 211)
        #expect(UInt8(255).prevPrime == 251)
        // the sequence, which walks by nextPrime
        #expect(Array(Int.primes.prefix(10)) == [2, 3, 5, 7, 11, 13, 17, 19, 23, 29])
        #expect(Array(UInt8.primes.prefix(5)) == [2, 3, 5, 7, 11])
        #expect(Array(Int.primes.prefix(200)) == BigInt.primes.prefix(200).map { Int($0) })
        #expect(Int.primes.first(where: { $0 > 1000 }) == 1009)
    }

    /// A 128-bit type is the one built-in that can hold a value past
    /// `UInt64.max`, which is the only place `isPrime` can be `nil` here.
    @Test func oneHundredTwentyEightBitIsTheExceptionToTheGuarantee() throws {
        guard #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) else { return }
        #expect(Int128(1000003).isPrime == true, "small values are settled as ever")
        #expect(Int128(1000001).isPrime == false)
        #expect(Int128(-7).isPrime == false)
        #expect(Int128(UInt64.max).isPrime == false, "at the guarantee's edge")
        // a prime above 2^64 is where a 128-bit type stops being able to force
        // unwrap: BPSW says prime, and nothing here proves it
        let past64 = Int128(BigInt(1) << 100)
        #expect(past64.nextPrime.isPrime == nil, "above 2^64, unproven")
        #expect(past64.nextPrime.isProbablePrime, "though BPSW still says prime")
        #expect((past64 + 1).isPrime == false, "a composite is settled at any size")
        // and it agrees with BigInt throughout
        #expect(Int128(1) << 100 == Int128(BigInt(1) << 100))
        #expect(past64.nextPrime == Int128(BigInt(past64).nextPrime))
        #expect(Int128(3).power(40, mod: 1_000_003)
                  == Int128(BigInt(3).power(40, mod: BigInt(1_000_003))))
    }
}
