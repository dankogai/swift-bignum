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
//  The other four do not refine the seed, and for π/4, ln 2 and ln 10 that is not
//  a limitation but a choice: each has a *quadratically* convergent method that
//  starts from nothing, and 512 seeded bits are not worth much against a method
//  whose correct-bit count doubles every pass.  Refining was measured, not assumed
//  -- Newton on ln 2 through `exp` came in at 193ms at 4096 bits against the AGM's
//  85ms, because each Newton step pays for a 537-term `exp` series.
//
//   *  π/4 runs Gauss-Legendre.
//   *  ln 2 runs `ln s = π/(2·AGM(1, 4/s))` with `s = 2ⁿ`, which is exactly the
//      case where the AGM's tiny starting value costs nothing: `4/2ⁿ` is a power
//      of two and `BigRat` holds it exactly.
//   *  ln 10 cannot use that -- `4/10ⁿ` is not dyadic, and `truncate` quantises on
//      an absolute grid, so the AGM loses about half its digits unless `working` is
//      widened to pay for it.  It goes through `LN2` and a short correction series
//      instead; see `LN10`.
//   *  e is the exception that really is from-scratch: its own series converges
//      superexponentially, so there is nothing to beat.
//
//  Nothing above caches, so each of these is paid again on every call.  That is
//  slower than a memo for a caller who asks repeatedly for 1024 bits, and it is
//  the trade being made: a correct answer with no shared state, against a faster
//  one with a lock around it.  Raising `seedBits` is the lever if the boundary is
//  in the wrong place -- the seeds are generated, not typed, and a wider one costs
//  only source size.
//
//  Where the time went, at 4096 bits, from the memoised original to now:
//
//      π/4      502ms -> 27ms      e     475ms -> 158ms
//      ln 2     3.2s  -> 85ms      √2    2.1ms -> 1.1ms
//      ln 10    3.8s  -> 172ms
//
//  Roughly half of that was not the formulae at all: it was `_gcd` learning that a
//  power-of-two operand shares nothing (BigUInt.swift), because every `truncate`
//  produces one and `BigRat` reduces every fraction it builds.  The loops here
//  contribute by keeping their accumulators truncated, so the reduction has that
//  shape to begin with.
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

    /// The arithmetic-geometric mean of 1 and `b0`.
    ///
    /// Each pass replaces the pair by its arithmetic and geometric means, which
    /// agree to twice as many bits as the pass before -- so the count of passes
    /// grows with the *logarithm* of the precision asked for.  `ATAN1` runs the
    /// same recurrence but has to accumulate two more variables along the way, so
    /// it keeps its own copy of the loop.
    internal static func _agm(_ b0:Self, working:Int, epsilon:Self, debug db:Bool = false)->Self {
        var a = Self(1)
        var b = b0
        var passes = 0
        while passes < 400 {
            let aNext = ((a + b) / 2).truncated(width: working)
            let bNext = (a * b).truncated(width: working)
                          .squareRoot(precision: working).truncated(width: working)
            passes += 1
            let converged = (aNext - bNext).magnitude < epsilon
            a = aNext
            b = bNext
            if db { print("\(Self.self)._agm: pass \(passes)") }
            if converged { break }
        }
        return a
    }

    /// `atanh z` by its series, for a `z` small enough that it converges quickly.
    ///
    /// `ElementaryFunctions` already has an `atanh`, but it goes by way of `log`,
    /// and `log` is the slow thing this file is trying not to call.
    internal static func _atanhSeries(_ z:Self, working:Int)->Self {
        let epsilon = getEpsilon(precision: working - 8)
        let z2 = (z * z).truncated(width: working)
        var t = z
        var r = z
        var k = 1
        while true {
            t = (t * z2).truncated(width: working)
            k += 1
            if t.magnitude < epsilon { break }
            // Truncated *before* it is added: `t / (2k-1)` has an odd denominator,
            // and adding that to the running sum gives the sum an odd factor too --
            // precisely the case the gcd fast path cannot help with, so every
            // addition would reduce the hard way.  Rounding the term to a
            // power-of-two denominator first keeps both sides cheap to reduce.
            var term = t / Self(2 * k - 1)
            term.truncate(width: working)
            r += term
            r.truncate(width: working)
        }
        return r
    }

    /// ln 2
    ///
    /// Truncated from the seed at or below 512 bits.  Above that, by the AGM:
    ///
    ///     ln s = π / (2 · AGM(1, 4/s))   to within O(s⁻² log s)
    ///
    /// so `s = 2ⁿ` with `n ≈ px/2` gives `n · ln 2` to the precision asked for.
    /// That choice of `s` is what makes this cheap here: `4/s` is an exact power of
    /// two, and `BigRat` holds it exactly, whatever `n` is.
    ///
    /// It replaced a `2·atanh(1/3)` series, which is correct and linear -- 1292
    /// terms at 4096 bits against the AGM's 20 passes.  Measured: 4096 bits 525ms
    /// to 85ms, 2048 82ms to 25ms, 1024 17ms to 7ms, and the gain widens with
    /// precision because the term count grows linearly while the pass count grows
    /// logarithmically.
    ///
    /// Newton-Raphson on the seed was the other candidate and lost: `x ← x - 1 +
    /// 2·exp(-x)` needs `exp`, whose series at 4096 bits is 537 terms, and it
    /// measured 193ms.  A quadratic method from scratch beats refining a seed when
    /// the seed's 512 bits are a small fraction of the answer.
    public static func LN2(precision px:Int = Self.precision, debug db:Bool = false)->Self {
        let apx = Swift.abs(px)
        if apx <= _Constant.seedBits { return Self(_Constant.ln2).truncated(width: apx) }
        if Self.self != BigRat.self { return Self(BigRat.LN2(precision: apx)) }
        let working = apx + 64
        // s = 2ⁿ, and the error in the formula above is O(s⁻²), so 2n bits of it
        // have to cover the answer -- n = apx/2 with a little to spare.
        let n = apx / 2 + 16
        let b0 = Self(BigRat(BigInt(1), BigInt(1) << (n - 2)))       // 4/2ⁿ, exact
        let m = _agm(b0, working: working,
                     epsilon: getEpsilon(precision: working - 16), debug: db)
        let pi = 4 * ATAN1(precision: working)
        return (pi / (2 * Self(n) * m)).truncated(width: apx)
    }

    /// ln 10
    ///
    /// Truncated from the seed at or below 512 bits.  Above that, from `LN2` and a
    /// short series, rather than from the AGM directly.
    ///
    /// The AGM would want `4/10ⁿ`, which is not a power of two -- and `truncate`
    /// quantises on an absolute grid (`Rational.swift`), so a value sitting 2288
    /// bits below 1 keeps only `working - 2288` significant bits.  Asking the AGM
    /// for ln 10 at 4096 bits that way returns 563 correct digits of 1231.
    /// Widening `working` to pay for it works and costs 211ms.
    ///
    /// This is faster.  `485/146` is a convergent of log₂10, so `2⁴⁸⁵/10¹⁴⁶` is
    /// within about 10⁻³ of 1:
    ///
    ///     ln 10 = (485 · ln 2 - ln(2⁴⁸⁵/10¹⁴⁶)) / 146
    ///
    /// and the correction, being a log of something near 1, is 188 series terms at
    /// 4096 bits rather than the 1292 that `log(10)` needed.  Measured at 4096
    /// bits: 1146ms to 172ms.  Later convergents converge faster still and later
    /// ones were tried -- `2136/643` reaches 155ms -- but their numerators are
    /// wider than the precision being asked for at ordinary widths, and `485/146`
    /// is the fastest of them below about a thousand bits.
    public static func LN10(precision px:Int = Self.precision, debug db:Bool = false)->Self {
        let apx = Swift.abs(px)
        if apx <= _Constant.seedBits { return Self(_Constant.ln10).truncated(width: apx) }
        if Self.self != BigRat.self { return Self(BigRat.LN10(precision: apx)) }
        let working = apx + 64
        let (k, m) = (485, 146)
        let tenToM = BigInt(10).power(m)
        // 2⁴⁸⁵/10¹⁴⁶ - 1, exactly; negative, as it happens
        let d = Self(BigRat((BigInt(1) << k) - tenToM, tenToM))
        // ln(1 + d) = 2 atanh(d / (2 + d))
        let z = (d / (2 + d)).truncated(width: working)
        let correction = 2 * _atanhSeries(z, working: working)
        if db { print("\(Self.self).LN10: correction = \(correction)") }
        return ((Self(k) * LN2(precision: working) - correction) / Self(m)).truncated(width: apx)
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
        // Gauss-Legendre.  `a` and `b` converge on their arithmetic-geometric mean
        // and the number of correct bits doubles every pass, so 4096 bits is ten
        // passes rather than the four hundred terms a Machin-like series needs.
        //
        // It replaced Bellard's formula here, which was correct and slower: at 4096
        // bits 68ms became 27ms, at 2048 15ms became 9ms.  Less than the change in
        // shape suggests, because each pass needs a square root and ours is not
        // asymptotically sharp -- so the advantage narrows as precision grows rather
        // than widening.  The cost now sits in a primitive that can be improved on
        // its own.
        //
        // `b` starts at 1/√2, which the seed above hands over for nothing.
        let working = apx + 64
        let epsilon = getEpsilon(precision: apx)
        var a = Self(1)
        var b = (SQRT2(precision: working) / 2).truncated(width: working)
        var t = Self(1) / Self(4)
        var p = Self(1)
        var passes = 0
        while passes < 64 {
            let aNext = ((a + b) / 2).truncated(width: working)
            let bNext = (a * b).truncated(width: working)
                          .squareRoot(precision: working).truncated(width: working)
            let d = (a - aNext).truncated(width: working)
            t = (t - p * d * d).truncated(width: working)
            p = p * 2
            passes += 1
            let converged = (aNext - bNext).magnitude < epsilon
            a = aNext
            b = bNext
            if db { print("\(Self.self).ATAN1: pass \(passes)") }
            if converged { break }
        }
        let sum = (a + b).truncated(width: working)
        // π = (a+b)²/4t, so π/4 is that over four again
        return (sum * sum / (16 * t)).truncated(width: apx)
    }
}
