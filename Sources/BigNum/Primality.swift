//
//  Primality.swift -- is it prime?
//
//  Ported from dankogai/swift2-pons's xtra_prime.swift, whose primality half
//  these are: Miller-Rabin on a chosen base, the Jacobi symbol, a Lucas
//  probable-prime test, Lucas-Lehmer for the Mersenne numbers, and BPSW built
//  out of the first two.  The factorization half of that file is not here.
//
//  All of it hangs off `BigIntegerType`, so `BigInt` and `BigUInt` share one
//  implementation.  Arbitrary precision simplifies the originals in two places:
//  `nextPrime` cannot run out of room, so it returns a value rather than an
//  Optional, and `isMersennePrime` recovers its exponent from the value itself
//  instead of from a fixed word size.
//
//  It also removes one, and that is the one departure worth knowing about.  The
//  original's `isPrime` was a `Bool`, which for a number past every deterministic
//  bound here means "BPSW found no witness" dressed as a fact.  Ours is a
//  `Bool?` and withholds that answer, so a caller has to decide what to do with
//  "unknown" instead of being handed a maybe.  The BPSW result itself is still
//  available, spelled `isProbablePrime`, and the two together are
//  `isSurelyPrime`.
//
//  `millerRabinTest(base:)` is the reason `power(_:mod:)` takes an exponent as
//  wide as `Self`: the exponent here is (self - 1) >> its trailing zeros.
//

extension BigIntegerType {

    // MARK: - Miller-Rabin

    /// `true` if `self` passes the [Miller-Rabin] test on `base` -- that is, if
    /// this base fails to witness `self` composite.  A single base proves
    /// compositeness but never primality, which is what `isPrime` and
    /// `isSurelyPrime` are for.
    ///
    /// [Miller-Rabin]: https://en.wikipedia.org/wiki/Miller%E2%80%93Rabin_primality_test
    public func millerRabinTest(base: Self) -> Bool {
        if self < 2      { return false }
        if self & 1 == 0 { return self == 2 }
        let last = self - 1
        // last == d * 2^s with d odd.  `t` tracks the exponent of `y`, so it
        // starts at d and doubles alongside each squaring.
        var d = last
        while d & 1 == 0 { d >>= 1 }
        var t = d
        var y = base.power(d, mod: self)
        while t != last && y != 1 && y != last {
            y = y * y % self
            t <<= 1
        }
        // Reaching -1 anywhere in the chain is a pass.  So is y == 1 on the
        // very first look, which `t & 1` detects: t is odd only before the
        // first doubling.  A 1 that appears *after* a squaring means the
        // previous y was a square root of 1 other than ±1, so `self` is
        // composite.
        return y == last || t & 1 == 1
    }

    // MARK: - the Jacobi symbol

    /// The [Jacobi symbol] (`i` / `self`), which is 0 unless `self` is odd and
    /// positive.
    ///
    /// [Jacobi symbol]: https://en.wikipedia.org/wiki/Jacobi_symbol
    public func jacobiSymbol(_ i: Int) -> Int {
        var m = self
        var n = Self(i.magnitude)
        var j = 1
        if m <= 0 || m & 1 == 0 { return 0 }
        if i < 0 && m % 4 == 3 { j = -j }
        while !n.isZero {
            while n & 1 == 0 {
                n >>= 1
                let m8 = m % 8
                if m8 == 3 || m8 == 5 { j = -j }
            }
            swap(&m, &n)
            if n % 4 == 3 && m % 4 == 3 { j = -j }
            n %= m
        }
        return m == 1 ? j : 0
    }

    // MARK: - Lucas

    /// `true` if `self` is a [Lucas probable prime] for the first Selfridge
    /// parameters -- D from 5, -7, 9, -11, ... the first with (D/self) == -1,
    /// then P = 1 and Q = (1 - D)/4.
    ///
    /// [Lucas probable prime]: https://en.wikipedia.org/wiki/Lucas_pseudoprime
    public var isLucasProbablePrime: Bool {
        if self < 2      { return false }
        if self & 1 == 0 { return self == 2 }
        // A perfect square has no D with (D/self) == -1, so the search below
        // would run off the end looking for one.
        let root = self.squareRoot()
        if root * root == self { return false }
        var d = 0
        for i in 2 ... 256 {                    // 256 is arbitrary, and ample
            let candidate = (i & 1 == 0 ? 1 : -1) * (2 * i + 1)
            if self.jacobiSymbol(candidate) == -1 { d = candidate ; break }
        }
        precondition(d != 0, "no D with (D/\(self)) == -1 -- is \(self) a square?")
        // The sequence runs in BigInt because Q is often negative.  Every D here
        // is 1 mod 4, so (1 - D)/4 is exact.
        let n = BigInt(self)
        let bd = BigInt(d)
        var q = (1 - bd) / 4
        var q2 = 2 * q
        var (u, v)   = (BigInt(0), BigInt(2))   // U_0, V_0
        var (u2, v2) = (BigInt(1), BigInt(1))   // U_1, V_1 == P == 1
        // Climb the bits of h = (self + 1)/2, doubling (u2, v2) each step and
        // folding it into (u, v) where the bit is set.
        var h = (n + 1) / 2
        while 0 < h {
            u2 *= v2
            u2 %= n
            v2 *= v2
            v2 -= q2
            v2 %= n
            if h & 1 == 1 {
                let t = u
                // U_{m+k} = (U_m V_k + U_k V_m) / 2, halved modulo n
                u *= v2
                u += u2 * v
                u += u & 1 == 0 ? 0 : n
                u /= 2
                u %= n
                // V_{m+k} = (V_m V_k + D U_m U_k) / 2, likewise
                v *= v2
                v += u2 * t * bd
                v += v & 1 == 0 ? 0 : n
                v /= 2
                v %= n
            }
            q *= q
            q %= n
            q2 = q << 1
            h >>= 1
        }
        // U_h == 0 is the pass.  Every prime with (D/self) == -1 reaches it:
        // across every odd number below 300000, `u` vanishes for all 25996 of
        // the primes and for only 132 of the composites -- and `v` vanishes for
        // none of either, so there is nothing to gain by also asking about it.
        return u.isZero
    }

    /// The [Lucas-Lehmer test], which settles a Mersenne number exactly.
    ///
    /// - returns: `true` if `self` is a Mersenne prime, `false` if it is a
    ///   composite Mersenne number, and `nil` if `self` is not 2^p - 1 at all.
    ///
    /// [Lucas-Lehmer test]: https://en.wikipedia.org/wiki/Lucas%E2%80%93Lehmer_primality_test
    public var isMersennePrime: Bool? {
        // self is 2^p - 1 exactly when self + 1 is a power of two, and then p is
        // where that power sits.  Recovering it this way needs no notion of a
        // word size, which is what the original had to consult.
        let next = self + 1
        guard 3 <= self, next & self == 0 else { return nil }
        let p = next.trailingZeroBitCount
        if p == 2 { return true }               // M2 == 3, below the recurrence
        // A composite p gives a composite Mp.  `isProbablePrime` rather than
        // `isPrime` for two reasons: p came from a bit count so it is far below
        // 2^64, where BPSW is exact and the Optional would only be noise; and
        // `isPrime` routes through `isSurelyPrime`, which calls back here.
        guard Self(p).isProbablePrime else { return false }
        // s -> s^2 - 2 (mod self), p - 2 times, from 4.  Reduction is by folding
        // rather than division: 2^p == 1 (mod 2^p - 1), so the high half of a
        // square can just be added to the low half.
        //
        // Both guards below are insurance rather than repairs.  A fold leaves a
        // sum under 2^(p+1), so a second subtraction is conceivable, and the
        // recurrence reaching s < 2 with an iteration still to go would make a
        // bare `s -= 2` underflow -- which for `BigUInt` is a trap, not a wrong
        // answer.  Neither fires for any prime exponent up to 1300; s == 1 does
        // arrive here at p == 4, which only a composite exponent could reach,
        // and those have already returned above.
        var s = Self(4)
        for _ in 0 ..< p - 2 {
            let square = s * s
            s = (square & self) + (square >> p)
            while self <= s { s -= self }
            s = 2 <= s ? s - 2 : s + self - 2
        }
        return s.isZero
    }

    // MARK: - BPSW

    /// `true` if `self` is prime according to the [Baillie-PSW] test: Miller-Rabin
    /// on base 2, then a Lucas probable-prime test.
    ///
    /// No composite is known to pass, and none below 2^64 exists -- that range
    /// has been checked exhaustively -- so this is exact for anything a `UInt64`
    /// could hold.  Above it, `true` means only that neither half found a
    /// witness, which is why `isPrime` withholds an answer there and this one is
    /// spelled "probable".
    ///
    /// [Baillie-PSW]: https://en.wikipedia.org/wiki/Baillie%E2%80%93PSW_primality_test
    public var isProbablePrime: Bool {
        if self < 2      { return false }
        if self & 1 == 0 { return self == 2 }
        if self % 3 == 0 { return self == 3 }
        if self % 5 == 0 { return self == 5 }
        if self % 7 == 0 { return self == 7 }
        return self.millerRabinTest(base: 2) && self.isLucasProbablePrime
    }

    /// ### [A014233]
    ///
    /// The smallest odd number that Miller-Rabin fails to expose using every
    /// base up to the n-th prime.  Below `A014233[i]`, passing the first `i + 1`
    /// prime bases *proves* primality.
    ///
    /// [A014233]: https://oeis.org/A014233
    public static var A014233: [Self] {
        return [
            Self("2047")!,                       // bases through 2
            Self("1373653")!,                    // 3
            Self("25326001")!,                   // 5
            Self("3215031751")!,                 // 7
            Self("2152302898747")!,              // 11
            Self("3474749660383")!,              // 13
            Self("341550071728321")!,            // 17
            Self("341550071728321")!,            // 19
            Self("3825123056546413051")!,        // 23
            Self("3825123056546413051")!,        // 29
            Self("3825123056546413051")!,        // 31
            Self("318665857834031151167461")!,   // 37
            Self("3317044064679887385961981")!,  // 41
        ]
    }

    /// The bases A014233 is indexed by.
    internal static var _A014233Bases: [Int] {
        return [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41]
    }

    /// Whether `self` is prime, and whether that answer is certain.
    ///
    /// `surely` is always `true` for a composite: a witness is a proof. For a
    /// prime it is `true` up to 3317044064679887385961981, the end of
    /// [A014233], and for any Mersenne number, which Lucas-Lehmer settles
    /// outright. Past that a `true` rests on BPSW, which no composite is known
    /// to pass but none is proven not to.
    ///
    /// [A014233]: https://oeis.org/A014233
    public var isSurelyPrime: (Bool, surely: Bool) {
        if self < 2      { return (false, true) }
        if self & 1 == 0 { return (self == 2, true) }
        if self % 3 == 0 { return (self == 3, true) }
        if self % 5 == 0 { return (self == 5, true) }
        if self % 7 == 0 { return (self == 7, true) }
        // BPSW is exhaustively verified below 2^64
        if self <= Self(UInt64.max) { return (self.isProbablePrime, true) }
        if let mersenne = self.isMersennePrime { return (mersenne, true) }
        let table = Self.A014233
        if self < table[table.count - 1] {
            for i in 0 ..< table.count {
                if !self.millerRabinTest(base: Self(Self._A014233Bases[i])) {
                    return (false, true)
                }
                if self < table[i] { return (true, true) }
            }
        }
        let prime = self.isProbablePrime
        return (prime, !prime)
    }

    /// Whether `self` is prime, or `nil` when no test here can settle it.
    ///
    ///     BigInt(1000003).isPrime                 // true
    ///     BigInt(1000001).isPrime                 // false
    ///     ((BigInt(1) << 300).nextPrime).isPrime  // nil -- probably prime, unproven
    ///
    /// A `false` is always a proof: a witness to compositeness is a witness. A
    /// `true` is a proof too -- below 2^64, below [A014233]'s last entry with
    /// thirteen Miller-Rabin bases, or for a Mersenne number through
    /// Lucas-Lehmer.  Past all of those, BPSW still has an opinion and this
    /// declines to launder it into a fact; `isProbablePrime` is that opinion and
    /// `isSurelyPrime` gives both halves at once.
    ///
    /// `nil` is not "no": treat it as one deliberately, with `== true`, rather
    /// than by reaching for `??`.
    ///
    /// **Never `nil` at or below `UInt64.max`.** That whole range is inside the
    /// exhaustively verified one, so if you know your values fit a `UInt64` --
    /// or are negative, or are anything else `Int`-sized -- the force unwrap is
    /// safe:
    ///
    ///     BigInt(1000003).isPrime!                // true, and cannot trap
    ///     BigInt(UInt64.max).isPrime!             // false
    ///
    /// [A014233]: https://oeis.org/A014233
    public var isPrime: Bool? {
        let (prime, surely) = self.isSurelyPrime
        return surely ? prime : nil
    }

    // MARK: - walking the primes

    /// The first prime greater than `self`.  Unlike the fixed-width original
    /// this cannot run out of room, so there is no Optional to unwrap.
    ///
    /// The search is on `isProbablePrime`, not `isPrime`: past the deterministic
    /// range `isPrime` is `nil`, and a walk that read that as "composite" would
    /// step over every candidate and never return.  So above 2^64 this is the
    /// next *probable* prime -- ask the result for its own `isSurelyPrime` if
    /// that distinction matters.
    public var nextPrime: Self {
        if self < 2 { return 2 }
        var u = self + (self & 1 == 0 ? 1 : 2)
        while !u.isProbablePrime { u += 2 }
        return u
    }

    /// The last prime less than `self`, or nil when there is none -- which is
    /// what 2 and everything below it gets.  Probable above 2^64, as
    /// `nextPrime` is.
    public var prevPrime: Self? {
        if self <= 2 { return nil }
        if self == 3 { return 2 }
        var u = self - (self & 1 == 0 ? 1 : 2)
        while !u.isProbablePrime { u -= 2 }
        return u
    }

    /// The primes from 2 upward, lazily and without end.
    ///
    ///     Array(BigInt.primes.prefix(5))      // [2, 3, 5, 7, 11]
    public static var primes: PrimeSequence<Self> {
        return PrimeSequence<Self>()
    }
}

/// An endless sequence of primes, in order.  `BigInt.primes` builds one.
public struct PrimeSequence<T: BigIntegerType> : Sequence, IteratorProtocol {
    private var current: T? = nil
    public init() {}
    public mutating func next() -> T? {
        let value = current.map { $0.nextPrime } ?? 2
        current = value
        return value
    }
}
