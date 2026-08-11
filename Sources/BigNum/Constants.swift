//
//  Constants.swift -- π/4, e, √2, ln 2 and ln 10, seeded rather than memoised.
//
//  These used to be cached in `static var`s, one per constant per type, filled in
//  on first use at whatever precision was asked for.  That was the only mutable
//  global state in the package and it was the source of its only data race: the
//  cached value owns a reference-counted array, so two threads filling one at once
//  corrupted a refcount rather than merely disagreeing about a number.  A lock
//  fixed the race and left the cache, which is a lot of machinery for a value that
//  never changes.
//
//  There is nothing to lock here.  Each constant is a literal, 640 bits wide and
//  used for requests up to 512,
//  stored as an exact rational with a power-of-two denominator.  A request at or
//  below 512 bits is a truncation of that literal -- no computation, no state, the
//  same answer every time in any order on any thread.  A request above it is
//  computed, and where the arithmetic allows, computed by *refining* the seed
//  rather than starting over.
//
//  √2 refines: Newton-Raphson on x² = 2 is `x ← (x + 2/x)/2`, which doubles the
//  number of correct bits per step and is self-correcting, so 512 good bits become
//  1024 in one division and 4096 in three.  Nothing it needs comes from this file,
//  which is what makes it safe to use here.
//
//  The other four do not refine, and the reason is circularity rather than effort:
//
//   *  ln 2 by Newton is `x ← x - 1 + 2·exp(-x)`, and `exp` reduces its argument
//      by ln 2.
//   *  π/4 by Newton wants a trigonometric function, and those reduce their
//      arguments by π.
//   *  ln 10 could be refined through `exp` (which needs only ln 2, so no cycle),
//      and e through `log` for the same reason -- but e's own series converges
//      superexponentially, so from-scratch is already fast, and ln 10 is one `log`
//      call either way.
//
//  Above 512 bits those four run the series they always ran, at the precision
//  asked for and without caching the result.  Those series were slow and are less
//  so: at 4096 bits pi/4 went from 502ms to 68ms, ln 2 from 3.2s to 0.8s, e from
//  475ms to 235ms and sqrt 2 from 2.1ms to 1.1ms.  Almost none of that came from
//  the loops -- it came from `_gcd` learning that a power-of-two operand shares
//  nothing (BigUInt.swift), because every `truncate` produces one and `BigRat`
//  reduces every fraction it builds.  The loops contribute by keeping their
//  accumulators truncated, so the reduction has that shape to begin with.  That is slower than a cache for a
//  caller who asks repeatedly for 1024 bits, and it is the trade being made: a
//  correct answer with no shared state, against a faster one with a lock around
//  it.  Raising `seedBits` is the lever if the boundary is in the wrong place --
//  the seeds are generated, not typed, and a wider one costs only source size.
//
//  The seeds are not this library's own output.  They were generated from Python's
//  `decimal` module -- √2 exactly, by integer square root -- and π/4 from the
//  published expansion, then checked to be 640 bits wide and within 2^-638 of the
//  true value.  Seeding a library from a constant it computed itself proves only
//  that it agrees with itself.
//

/// The seeds, and how far they can be trusted.
///
/// `static let` on a concrete type, so initialisation happens once and is
/// thread-safe, and no code path ever assigns to them.
internal enum _Constant {
    /// Every seed here is exact to this many bits.  A request at or below it is
    /// answered by truncation.
    /// Requests at or below this are answered by truncating a seed.
    internal static let seedBits = 512
    /// Each seed is actually this wide.  The extra bits are headroom: a seed
    /// truncated at exactly `seedBits` would carry up to a whole unit of its own
    /// truncation error into the answer, which is how `LN10` at 512 bits used to
    /// come back a shade over one ulp out.  128 spare bits cost nothing but source.
    internal static let seedWidth = 640

    /// √2
    internal static let sqrt2 = _seed("b504f333f9de6484597d89b3754abe9f1d6f60ba893ba84ced17ac85833399154afc83043ab8a2c3a8b1fe6fdc83db390f74a85e439c7b4a780487363dfa2768d2202e8742af1f4e53059c6011bc337b", 639)
    /// e
    internal static let e = _seed("adf85458a2bb4a9aafdc5620273d3cf1d8b9c583ce2d3695a9e13641146433fbcc939dce249b3ef97d2fe363630c75d8f681b202aec4617ad3df1ed5d5fd65612433f51f5f066ed0856365553ded1af3", 638)
    /// ln 2
    internal static let ln2 = _seed("b17217f7d1cf79abc9e3b39803f2f6af40f343267298b62d8a0d175b8baafa2be7b876206debac98559552fb4afa1b10ed2eae35c138214427573b291169b8253e96ca16224ae8c51acbda11317c387e", 640)
    /// ln 10
    internal static let ln10 = _seed("935d8dddaaa8ac16ea56d62b82d30a28e28fecf9da5df90e83c61e8201f02d72962f02d7b1a8105ccc70cbc02c5f0d682c622418410be2dafb8f788402e516d6782cf8a28a8c911e765aa6c3b0d831fb", 638)
    /// π/4
    internal static let atan1 = _seed("c90fdaa22168c234c4c6628b80dc1cd129024e088a67cc74020bbea63b139b22514a08798e3404ddef9519b3cd3a431b302b0a6df25f14374fe1356d6d51c245e485b576625e7ec6f44c42e9a637ed6b", 640)

    /// `mantissa / 2^shift`, exactly -- a power-of-two denominator, so truncating
    /// it to any width below `seedBits` is a shift and not a division.
    private static func _seed(_ mantissa: String, _ shift: Int) -> BigRat {
        return BigRat(BigInt(mantissa, radix: 16)!, BigInt(1) << shift)
    }
}

extension BigFloatingPoint {

    /// √2
    ///
    /// Truncated from the seed at or below 512 bits.  Above that, Newton-Raphson
    /// from the seed: `x ← (x + 2/x)/2` doubles the correct bits each step, so
    /// four thousand bits is three divisions away from five hundred.
    public static func SQRT2(precision px:Int = Self.precision, debug db:Bool = false)->Self {
        let apx = Swift.abs(px)
        if apx <= _Constant.seedBits { return Self(_Constant.sqrt2).truncated(width: apx) }
        var x = Self(_Constant.sqrt2)
        var good = _Constant.seedBits
        while good < apx {
            // Each step doubles the correct bits; carry a few spare so the last
            // one is not decided by the rounding of the step before it.
            good = Swift.min(good * 2, apx)
            let working = good + 16
            x = ((x + Self(2).divided(by: x, precision: working)) / 2).truncated(width: working)
            if db { print("\(Self.self).SQRT2: refined to \(good) bits") }
        }
        return x.truncated(width: apx)
    }

    /// e
    ///
    /// Truncated from the seed at or below 512 bits; above that, summed as
    /// `Σ 1/n!`, which converges superexponentially and needs no seed to be quick.
    public static func E(precision px:Int = Self.precision, debug db:Bool = false)->Self {
        let apx = Swift.abs(px)
        if apx <= _Constant.seedBits { return Self(_Constant.e).truncated(width: apx) }
        if Self.self != BigRat.self { return Self(BigRat.E(precision: apx)) }
        let epsilon = getEpsilon(precision: apx)
        let working = apx + 64
        // `t` is carried and divided rather than rebuilt as `1/i!`.  Keeping the
        // factorial exact meant `d` grew a few bits per term and every reciprocal
        // was taken against all of it; dividing the running term instead keeps both
        // operands the same bounded size.
        var (e, t) = (Self(1), Self(1))
        for i in 1 ... apx {
            t /= Self(i)
            t.truncate(width: working)
            if t < epsilon { break }
            e += t
            e.truncate(width: working)
        }
        return e.truncated(width: apx)
    }

    /// ln 2
    ///
    /// Truncated from the seed at or below 512 bits.  Above that, the same
    /// `atanh`-style series as before -- Newton on this one would want `exp`,
    /// which reduces its argument by ln 2.
    public static func LN2(precision px:Int = Self.precision, debug db:Bool = false)->Self {
        let apx = Swift.abs(px)
        if apx <= _Constant.seedBits { return Self(_Constant.ln2).truncated(width: apx) }
        if Self.self != BigRat.self { return Self(BigRat.LN2(precision: apx)) }
        let epsilon = getEpsilon(precision: apx)
        let working = apx + 64          // see ATAN1 for why the sum is bounded
        var (t, r) = (Self(1)/Self(3), Self(1)/Self(3))
        for i in 1 ... apx.magnitude {
            t *= Self(1)/Self(9)
            t.truncate(width: working)
            if db { print("\(Self.self).LN2: i=\(i)") }
            if t < epsilon { break }
            // Truncated *before* it is added.  `t / (2i+1)` has an odd denominator,
            // and adding that to the running sum gives the sum an odd factor too --
            // which is precisely the case the gcd fast path cannot help with, so
            // every addition would reduce the hard way.  Rounding the term to a
            // power-of-two denominator first keeps both sides cheap to reduce.
            var term = t / Self(2 * i + 1)
            term.truncate(width: working)
            r += term
            r.truncate(width: working)
        }
        return (2*r).truncated(width: apx)
    }

    /// ln 10
    ///
    /// Truncated from the seed at or below 512 bits; above that, one `log` call,
    /// which is what a Newton step would have cost anyway.
    public static func LN10(precision px:Int = Self.precision, debug db:Bool = false)->Self {
        let apx = Swift.abs(px)
        if apx <= _Constant.seedBits { return Self(_Constant.ln10).truncated(width: apx) }
        return Self.log(10, precision: apx).truncated(width: apx)
    }

    /// π/4
    ///
    /// Truncated from the seed at or below 512 bits.  Above that, the same
    /// Machin-like series as before -- Newton would want a trigonometric
    /// function, and those reduce their arguments by π.
    public static func ATAN1(precision px:Int = Self.precision, debug db:Bool = false)->Self {
        if leastNormalMagnitude != 0 {  // FIXME: this trick is dirty
            return Self.pi / 4
        }
        let apx = Swift.abs(px)
        if apx <= _Constant.seedBits { return Self(_Constant.atan1).truncated(width: apx) }
        if Self.self != BigRat.self { return Self(BigRat.ATAN1(precision: apx)) }
        let epsilon = getEpsilon(precision: apx)
        // Working width for the running sum.  Without this the sum is an *exact*
        // rational, so its denominator becomes the least common multiple of every
        // term's -- one new odd factor and ten more powers of two per iteration --
        // and the arithmetic slows down as it goes.  Truncating each step holds the
        // denominator at a power of two of fixed size.  The spare bits cover the
        // truncation error accumulating over the iterations: there are about
        // `apx/10` of them, so 64 is generous.
        let working = apx + 64
        var p64 = Self(0)
        for i in 0 ..< Int(apx.magnitude) {
            var t = Self(0)
            t -= Self(1<<5) / Self( 4 * i + 1)
            t -= Self(1<<0) / Self( 4 * i + 3)
            t += Self(1<<8) / Self(10 * i + 1)
            t -= Self(1<<6) / Self(10 * i + 3)
            t -= Self(1<<2) / Self(10 * i + 5)
            t -= Self(1<<2) / Self(10 * i + 7)
            t += Self(1<<0) / Self(10 * i + 9)
            if 0 < i { t /= Self(IntType(1) << (10 * i)) }
            // Truncated as well as the sum: with a power-of-two denominator on both
            // sides the addition is a shift and an add, where an exact term would
            // drag its own odd factors through every remaining iteration.
            t.truncate(width: working)
            // The terms alternate.  Dropping this sign is exactly the mistake I
            // made transcribing the series, and no test below 512 bits could see
            // it, since those are answered by the seed.
            p64 += i & 1 == 1 ? -t : t
            p64.truncate(width: working)
            if db && i % 16 == 0 { print("\(Self.self).ATAN1: i=\(i)") }
            if t < epsilon { break }
        }
        return (p64 / Self(1<<8)).truncated(width: apx)
    }
}
