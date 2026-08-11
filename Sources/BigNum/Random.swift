//
//  Random.swift -- random integers of a chosen width or within a chosen range.
//
//  attaswift/BigInt spells these `randomInteger(...)`; here they are `random(...)`,
//  since the type is the noun and repeating it in the method name says nothing.
//  The three width-and-limit forms are its, the range form is not:
//
//      BigUInt.random(withMaximumWidth: 1024)    // 0 ..< 2^1024
//      BigUInt.random(withExactWidth: 1024)      // exactly 1024 bits, so 2^1023 ..< 2^1024
//      BigUInt.random(lessThan: n)               // 0 ..< n
//      BigInt.random(from: -100, to: 100)        // -100 ... 100, both ends included
//
//  Each takes an optional `using generator: inout some RandomNumberGenerator`;
//  without one they use `SystemRandomNumberGenerator`.
//
//  `random(from:to:)` is **closed** -- `to:` is reachable. That reads against
//  Swift's usual habit, where `to:` excludes and `through:` includes, but the
//  useful thing about an arbitrary-precision range is that its ends are both
//  ordinary values with nothing special about either, and "pick a number between
//  these two" wants both. The label is `to:` rather than `through:` because that
//  is what was asked for; the documentation says which it is at every mention.
//
//  `lessThan:` and the range form both sample without bias, by rejection: draw
//  exactly as many bits as the bound needs and draw again if the result is out of
//  range. That discards under half of the draws, so the expected number of tries
//  is below two, and no value is more likely than another. Scaling a draw down
//  with `%` would have been one line and would have skewed the low end.
//

// MARK: - the limb-level generators

/// `width` fresh random bits, as limbs.  The top limb is masked to whatever part
/// of it the width asks for.
internal func _randomLimbs<R:RandomNumberGenerator>(bits width: Int,
                                                    using g: inout R) -> [UInt] {
    precondition(width >= 0, "a random value cannot have \(width) bits")
    if width == 0 { return [] }
    let whole = width / UInt.bitWidth
    let extra = width % UInt.bitWidth
    var limbs = [UInt]()
    limbs.reserveCapacity(whole + (extra == 0 ? 0 : 1))
    for _ in 0 ..< whole { limbs.append(g.next()) }
    if extra != 0 { limbs.append(g.next() & ((1 << UInt(extra)) - 1)) }
    _normalize(&limbs)
    return limbs
}

/// The same, but with the top bit set, so the result is exactly `width` bits
/// wide.  A width of 0 is zero, which is the only value with no bits at all.
internal func _randomLimbs<R:RandomNumberGenerator>(exactBits width: Int,
                                                    using g: inout R) -> [UInt] {
    precondition(width >= 0, "a random value cannot have \(width) bits")
    if width == 0 { return [] }
    var limbs = _randomLimbs(bits: width, using: &g)
    let index = (width - 1) / UInt.bitWidth
    while limbs.count <= index { limbs.append(0) }
    limbs[index] |= 1 << UInt((width - 1) % UInt.bitWidth)
    return limbs
}

/// A value in `0 ..< limit`, uniformly.  `limit` must be non-zero.
internal func _randomLimbs<R:RandomNumberGenerator>(lessThan limit: [UInt],
                                                    using g: inout R) -> [UInt] {
    precondition(!limit.isEmpty, "random(lessThan: 0) has nothing to return")
    let top = limit[limit.count - 1]
    let width = (limit.count - 1) * UInt.bitWidth + (UInt.bitWidth - top.leadingZeroBitCount)
    // Rejection, not remainder: a draw of exactly `width` bits lands below the
    // limit better than half the time, so this returns quickly and evenly.
    while true {
        let candidate = _randomLimbs(bits: width, using: &g)
        if _compare(candidate, limit) < 0 { return candidate }
    }
}

// MARK: - BigUInt

extension BigUInt {
    /// A uniform value in `0 ..< 2^width`.
    public static func random<R:RandomNumberGenerator>(withMaximumWidth width: Int,
                                                       using generator: inout R) -> BigUInt {
        return BigUInt(normalized: _randomLimbs(bits: width, using: &generator))
    }
    /// A uniform value that is exactly `width` bits wide, i.e. in
    /// `2^(width-1) ..< 2^width`.  Zero for a width of 0.
    public static func random<R:RandomNumberGenerator>(withExactWidth width: Int,
                                                       using generator: inout R) -> BigUInt {
        return BigUInt(normalized: _randomLimbs(exactBits: width, using: &generator))
    }
    /// A uniform value in `0 ..< limit`.  Traps on a limit of zero, which has no
    /// value below it.
    public static func random<R:RandomNumberGenerator>(lessThan limit: BigUInt,
                                                       using generator: inout R) -> BigUInt {
        return BigUInt(normalized: _randomLimbs(lessThan: limit.limbs, using: &generator))
    }
    /// A uniform value in `lower ... upper`, **both ends included**.  Traps when
    /// `upper` is below `lower`.
    public static func random<R:RandomNumberGenerator>(from lower: BigUInt, to upper: BigUInt,
                                                       using generator: inout R) -> BigUInt {
        precondition(lower <= upper, "random(from: \(lower), to: \(upper)) is an empty range")
        if lower == upper { return lower }
        // upper - lower + 1 cannot overflow here, there being no ceiling to hit
        return lower + random(lessThan: upper - lower + 1, using: &generator)
    }

    public static func random(withMaximumWidth width: Int) -> BigUInt {
        var g = SystemRandomNumberGenerator()
        return random(withMaximumWidth: width, using: &g)
    }
    public static func random(withExactWidth width: Int) -> BigUInt {
        var g = SystemRandomNumberGenerator()
        return random(withExactWidth: width, using: &g)
    }
    public static func random(lessThan limit: BigUInt) -> BigUInt {
        var g = SystemRandomNumberGenerator()
        return random(lessThan: limit, using: &g)
    }
    public static func random(from lower: BigUInt, to upper: BigUInt) -> BigUInt {
        var g = SystemRandomNumberGenerator()
        return random(from: lower, to: upper, using: &g)
    }
}

// MARK: - BigInt
//
// The width forms return non-negative values: a width says how many bits the
// magnitude has and says nothing about a sign, and a caller who wants one either
// way can negate on a coin flip.  `random(from:to:)` spans negatives happily,
// since it works on the difference.

extension BigInt {
    /// A uniform **non-negative** value in `0 ..< 2^width`.
    public static func random<R:RandomNumberGenerator>(withMaximumWidth width: Int,
                                                       using generator: inout R) -> BigInt {
        return BigInt(magnitude: _randomLimbs(bits: width, using: &generator), negative: false)
    }
    /// A uniform **non-negative** value exactly `width` bits wide.
    public static func random<R:RandomNumberGenerator>(withExactWidth width: Int,
                                                       using generator: inout R) -> BigInt {
        return BigInt(magnitude: _randomLimbs(exactBits: width, using: &generator), negative: false)
    }
    /// A uniform value in `0 ..< limit`.  Traps unless `limit` is positive.
    public static func random<R:RandomNumberGenerator>(lessThan limit: BigInt,
                                                       using generator: inout R) -> BigInt {
        precondition(limit > 0, "random(lessThan: \(limit)) has nothing to return")
        return BigInt(magnitude: _randomLimbs(lessThan: limit.magnitudeLimbs, using: &generator),
                      negative: false)
    }
    /// A uniform value in `lower ... upper`, **both ends included**, negative
    /// bounds included.  Traps when `upper` is below `lower`.
    public static func random<R:RandomNumberGenerator>(from lower: BigInt, to upper: BigInt,
                                                       using generator: inout R) -> BigInt {
        precondition(lower <= upper, "random(from: \(lower), to: \(upper)) is an empty range")
        if lower == upper { return lower }
        return lower + random(lessThan: upper - lower + 1, using: &generator)
    }

    public static func random(withMaximumWidth width: Int) -> BigInt {
        var g = SystemRandomNumberGenerator()
        return random(withMaximumWidth: width, using: &g)
    }
    public static func random(withExactWidth width: Int) -> BigInt {
        var g = SystemRandomNumberGenerator()
        return random(withExactWidth: width, using: &g)
    }
    public static func random(lessThan limit: BigInt) -> BigInt {
        var g = SystemRandomNumberGenerator()
        return random(lessThan: limit, using: &g)
    }
    public static func random(from lower: BigInt, to upper: BigInt) -> BigInt {
        var g = SystemRandomNumberGenerator()
        return random(from: lower, to: upper, using: &g)
    }
}

// MARK: - and the built-in integers
//
// `Int`, `UInt`, `Int8` ... `UInt64`, and `Int128` where the platform has it.
// Same delegation as everything else in FixedWidthInteger.swift: the work happens
// in `BigInt` and the answer comes back, trapping if it does not fit.  So
// `Int8.random(withMaximumWidth: 100)` traps, exactly as `Int8(2).power(100)`
// does, while `random(from:to:)` cannot -- its answer is between two values the
// type already holds.
//
// The standard library's `random(in:)` is untouched and remains the idiomatic
// spelling for a fixed-width range; these are here so that generic code can say
// `T.random(...)` for any integer this package touches.

extension FixedWidthInteger {
    /// A uniform non-negative value in `0 ..< 2^width`.  Traps unless it fits.
    public static func random<R:RandomNumberGenerator>(withMaximumWidth width: Int,
                                                       using generator: inout R) -> Self {
        return Self(BigInt.random(withMaximumWidth: width, using: &generator))
    }
    /// A uniform non-negative value exactly `width` bits wide.  Traps unless it
    /// fits -- note `Int64.random(withExactWidth: 64)` does not, since that width
    /// needs the sign bit.
    public static func random<R:RandomNumberGenerator>(withExactWidth width: Int,
                                                       using generator: inout R) -> Self {
        return Self(BigInt.random(withExactWidth: width, using: &generator))
    }
    /// A uniform value in `0 ..< limit`.
    public static func random<R:RandomNumberGenerator>(lessThan limit: Self,
                                                       using generator: inout R) -> Self {
        return Self(BigInt.random(lessThan: BigInt(limit), using: &generator))
    }
    /// A uniform value in `lower ... upper`, **both ends included**.  Cannot
    /// overflow: the result lies between two values of this type.
    public static func random<R:RandomNumberGenerator>(from lower: Self, to upper: Self,
                                                       using generator: inout R) -> Self {
        return Self(BigInt.random(from: BigInt(lower), to: BigInt(upper), using: &generator))
    }

    public static func random(withMaximumWidth width: Int) -> Self {
        var g = SystemRandomNumberGenerator()
        return random(withMaximumWidth: width, using: &g)
    }
    public static func random(withExactWidth width: Int) -> Self {
        var g = SystemRandomNumberGenerator()
        return random(withExactWidth: width, using: &g)
    }
    public static func random(lessThan limit: Self) -> Self {
        var g = SystemRandomNumberGenerator()
        return random(lessThan: limit, using: &g)
    }
    public static func random(from lower: Self, to upper: Self) -> Self {
        var g = SystemRandomNumberGenerator()
        return random(from: lower, to: upper, using: &g)
    }
}
