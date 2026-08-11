//
//  BigInt.swift -- an arbitrary-precision signed integer, in two's complement.
//
//  The usual way to build one of these is sign-and-magnitude: a `Bool` beside a
//  `BigUInt`.  It makes multiplication and division trivial and everything else
//  a special case -- `&`, `|`, `^`, `~` and `>>` all have to be re-derived from
//  the two's complement definitions they are specified in terms of, negative
//  zero becomes representable and has to be legislated away, and `words` (which
//  `BinaryInteger` defines *as* the two's complement representation) has to be
//  synthesized limb by limb.
//
//  So this stores two's complement instead: little-endian limbs whose most
//  significant bit repeats infinitely to the left.  `words`, the four bitwise
//  operators, both shifts and comparison then read straight off the storage, and
//  addition needs nothing but sign extension.  Multiplication, division and
//  square root are the ones that pay, by going through `magnitude` -- but those
//  are the operations whose cost is dominated by the limb loop anyway.
//
//  Normalization keeps the array as short as it can be: a top limb of 0 goes
//  away when the limb below it is also non-negative, and a top limb of all-ones
//  goes away when the limb below it is also negative.  Zero is the empty array,
//  and -1 is `[UInt.max]`.
//

/// Trims the sign-extension limbs that carry no information.
@inline(__always)
internal func _normalizeSigned(_ limbs: inout [UInt]) {
    let signBit = UInt.bitWidth - 1
    while let top = limbs.last {
        if limbs.count == 1 {
            if top == 0 { limbs.removeLast() }  // the only redundant one-limb form
            return
        }
        let below = limbs[limbs.count - 2] >> signBit
        if top == 0        && below == 0 { limbs.removeLast() ; continue }
        if top == UInt.max && below == 1 { limbs.removeLast() ; continue }
        return
    }
}

///
/// An arbitrary-precision signed integer.
///
public struct BigInt : BigIntType, Hashable {
    public typealias Words = [UInt]
    public typealias Stride = BigInt
    public typealias Magnitude = BigUInt
    public typealias IntegerLiteralType = Int64

    /// Little-endian two's complement limbs with the top bit sign-extended to
    /// infinity.  Empty is zero; see `_normalizeSigned(_:)` for the invariant.
    @usableFromInline internal var limbs: [UInt]

    /// Assigns before normalizing, so a caller handing over a uniquely-referenced
    /// array gets the trim in place instead of a copy.
    @usableFromInline internal init(limbs: [UInt]) {
        self.limbs = limbs
        _normalizeSigned(&self.limbs)
    }
    /// Builds a signed value out of an unsigned magnitude.
    @usableFromInline internal init(magnitude: [UInt], negative: Bool) {
        var l = _normalized(magnitude)
        if l.isEmpty { self.limbs = [] ; return }
        // A magnitude may legitimately fill its top limb, which would read as
        // negative; give it a clear sign limb before complementing.
        if l[l.count - 1] >> (UInt.bitWidth - 1) == 1 { l.append(0) }
        if negative { l = _negate(l) }
        _normalizeSigned(&l)
        self.limbs = l
    }
    public init() {
        self.limbs = []
    }
}

extension BigInt {
    public static var isSigned: Bool { return true }
    public var words: [UInt]         { return limbs.isEmpty ? [0] : limbs }
    public var isZero: Bool          { return limbs.isEmpty }

    /// Whether the infinitely repeated top bit is 1.
    @inline(__always) public var isNegative: Bool {
        guard let top = limbs.last else { return false }
        return top >> (UInt.bitWidth - 1) == 1
    }
    /// The limb that stands in for every position above the stored ones.
    @inline(__always) internal var signExtension: UInt {
        return isNegative ? UInt.max : 0
    }
    @inline(__always) internal func limb(_ i: Int) -> UInt {
        return i < limbs.count ? limbs[i] : signExtension
    }
    /// The magnitude in one limb, when it fits -- without building an array.
    ///
    /// Limb *count* is the wrong question: a positive value with its top bit set
    /// carries a clear sign limb above it, so 2^63 is two limbs wide while its
    /// magnitude is one. Every value an `Int` can hold lands here.
    @inline(__always) internal var singleLimbMagnitude: UInt? {
        switch limbs.count {
        case 0:
            return 0
        case 1:
            return isNegative ? 0 &- limbs[0] : limbs[0]
        case 2:
            // With sign extension, [lo, 0] is +lo and [lo, ~0] is lo - 2^64.
            if limbs[1] == 0 { return limbs[0] }
            if limbs[1] == UInt.max && limbs[0] != 0 { return 0 &- limbs[0] }
            return nil
        default:
            return nil
        }
    }
    /// The stored limbs re-read as an unsigned magnitude.
    @usableFromInline internal var magnitudeLimbs: [UInt] {
        return isNegative ? _normalized(_negate(limbs)) : _normalized(limbs)
    }
    public var magnitude: BigUInt {
        return BigUInt(normalized: magnitudeLimbs)
    }

    /// Significant bits of the magnitude, plus one for the sign -- so 0 is 0 bits
    /// wide, ±1 are 2 and ±2 are 3.  This is what `BigNum` reads as "the position
    /// of the top set bit, plus a sign bit", and it deliberately does not use the
    /// tighter two's complement width in which -2 fits in 2 bits.
    public var bitWidth: Int {
        if limbs.isEmpty { return 0 }
        let width = UInt.bitWidth
        if !isNegative {
            var i = limbs.count - 1
            while 0 <= i && limbs[i] == 0 { i -= 1 }    // the sign-guard limb
            if i < 0 { return 0 }
            return i * width + (width - limbs[i].leadingZeroBitCount) + 1
        }
        // Walk the magnitude's limbs from the top without materializing them:
        // negation complements every limb above the lowest non-zero one, and
        // negates that one.
        var lowest = 0
        while limbs[lowest] == 0 { lowest += 1 }        // a negative value has a set bit
        var i = limbs.count - 1
        while lowest <= i {
            let limb = i == lowest ? ~limbs[i] &+ 1 : ~limbs[i]
            if limb != 0 { return i * width + (width - limb.leadingZeroBitCount) + 1 }
            i -= 1
        }
        return 0
    }
    /// Negation leaves the trailing zeros alone, so the stored limbs answer this
    /// for either sign.  Zero reports 0 rather than diverging.
    public var trailingZeroBitCount: Int {
        for (i, limb) in limbs.enumerated() where limb != 0 {
            return i * UInt.bitWidth + limb.trailingZeroBitCount
        }
        return 0
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(limbs)
    }
}

// MARK: conversion in

extension BigInt {
    public init(integerLiteral value: Int64) {
        self.init(value)
    }
    public init<T: BinaryInteger>(_ source: T) {
        var l = source.words.map { $0 }
        // A signed source already hands over sign-extended two's complement; an
        // unsigned one needs a clear sign limb when its top bit is set.
        if !T.isSigned, let top = l.last, top >> (UInt.bitWidth - 1) == 1 { l.append(0) }
        self.init(limbs: l)
    }
    public init?<T: BinaryInteger>(exactly source: T) {
        self.init(source)
    }
    /// Nothing to truncate to, and nothing to clamp against.
    public init<T: BinaryInteger>(truncatingIfNeeded source: T) { self.init(source) }
    public init<T: BinaryInteger>(clamping source: T)           { self.init(source) }

    public init(_ magnitude: BigUInt, negative: Bool = false) {
        self.init(magnitude: magnitude.limbs, negative: negative)
    }
    public init?<T: BinaryFloatingPoint>(exactly source: T) {
        guard let m = BigUInt(exactly: source.magnitude) else { return nil }
        self.init(m, negative: source.sign == .minus)
    }
    public init<T: BinaryFloatingPoint>(_ source: T) {
        guard let v = BigInt(exactly: source.rounded(.towardZero)) else {
            preconditionFailure("\(source) cannot be a BigInt")
        }
        self = v
    }
}

// MARK: comparison

extension BigInt : Comparable {
    public static func == (lhs: BigInt, rhs: BigInt) -> Bool {
        return lhs.limbs == rhs.limbs   // normalization makes the form canonical
    }
    public static func < (lhs: BigInt, rhs: BigInt) -> Bool {
        if lhs.isNegative != rhs.isNegative { return lhs.isNegative }
        // Same sign, so the sign-extended limbs compare as unsigned.
        var i = Swift.max(lhs.limbs.count, rhs.limbs.count) - 1
        while 0 <= i {
            let (x, y) = (lhs.limb(i), rhs.limb(i))
            if x != y { return x < y }
            i -= 1
        }
        return false
    }
}

// MARK: additive arithmetic

extension BigInt {
    public static func + (lhs: BigInt, rhs: BigInt) -> BigInt {
        // One limb above the wider operand is always enough room for the sum.
        let n = Swift.max(lhs.limbs.count, rhs.limbs.count) + 1
        var r = [UInt]()
        r.reserveCapacity(n)
        var carry = false
        for i in 0 ..< n {
            var (s, o1) = lhs.limb(i).addingReportingOverflow(rhs.limb(i))
            var o2 = false
            if carry { (s, o2) = s.addingReportingOverflow(1) }
            r.append(s)
            carry = o1 || o2
        }
        return BigInt(limbs: r)
    }
    public static prefix func - (x: BigInt) -> BigInt {
        // Widen by a sign limb first: negating -2^63 needs somewhere to put the
        // bit that +2^63 does not fit in.
        var l = x.limbs
        l.append(x.signExtension)
        return BigInt(limbs: _negate(l))
    }
    public static prefix func + (x: BigInt) -> BigInt {
        return x
    }
    /// `lhs + ~rhs + 1`, which is what two's complement subtraction *is* -- one
    /// pass and one allocation.  Written as `lhs + (-rhs)` it was three of each,
    /// and cost 2.3-2.5x our own `+` at every operand size while attaswift's `-`
    /// was never slower than its `+`.
    public static func - (lhs: BigInt, rhs: BigInt) -> BigInt {
        let n = Swift.max(lhs.limbs.count, rhs.limbs.count) + 1
        var r = [UInt]()
        r.reserveCapacity(n)
        var carry = true                    // the +1
        for i in 0 ..< n {
            var (s, o1) = lhs.limb(i).addingReportingOverflow(~rhs.limb(i))
            var o2 = false
            if carry { (s, o2) = s.addingReportingOverflow(1) }
            r.append(s)
            carry = o1 || o2
        }
        return BigInt(limbs: r)
    }
    public mutating func negate() {
        self = -self
    }
    public static func += (lhs: inout BigInt, rhs: BigInt) { lhs = lhs + rhs }
    public static func -= (lhs: inout BigInt, rhs: BigInt) { lhs = lhs - rhs }
}

// MARK: multiplicative arithmetic
//
// These are the three that two's complement does not do for free, so they go
// out to the magnitude and come back with a sign.

extension BigInt {
    public static func * (lhs: BigInt, rhs: BigInt) -> BigInt {
        // One limb each is the common case, and the general path spends four
        // allocations on it: two magnitudes, the product, and the signed result.
        // `multipliedFullWidth` needs none of them.  A one-limb value has
        // magnitude at most 2^63, so both magnitudes fit a `UInt`.
        if let x = lhs.singleLimbMagnitude, let y = rhs.singleLimbMagnitude {
            if x == 0 || y == 0 { return BigInt() }
            let (high, low) = x.multipliedFullWidth(by: y)
            return BigInt(magnitude: high == 0 ? [low] : [low, high],
                          negative: lhs.isNegative != rhs.isNegative)
        }
        return BigInt(magnitude: _multiply(lhs.magnitudeLimbs, rhs.magnitudeLimbs),
                      negative: lhs.isNegative != rhs.isNegative)
    }
    /// Truncating division, as `BinaryInteger` specifies: the quotient rounds
    /// toward zero and the remainder takes the dividend's sign.
    public func quotientAndRemainder(dividingBy other: BigInt)
      -> (quotient: BigInt, remainder: BigInt)
    {
        let (q, r) = _divide(self.magnitudeLimbs, other.magnitudeLimbs)
        return (BigInt(magnitude: q, negative: self.isNegative != other.isNegative),
                BigInt(magnitude: r, negative: self.isNegative))
    }
    public static func / (lhs: BigInt, rhs: BigInt) -> BigInt {
        return lhs.quotientAndRemainder(dividingBy: rhs).quotient
    }
    public static func % (lhs: BigInt, rhs: BigInt) -> BigInt {
        return lhs.quotientAndRemainder(dividingBy: rhs).remainder
    }
    public static func *= (lhs: inout BigInt, rhs: BigInt) { lhs = lhs * rhs }
    public static func /= (lhs: inout BigInt, rhs: BigInt) { lhs = lhs / rhs }
    public static func %= (lhs: inout BigInt, rhs: BigInt) { lhs = lhs % rhs }

    public func squareRoot() -> BigInt {
        precondition(!isNegative, "square root of a negative BigInt")
        return BigInt(magnitude.squareRoot())
    }
    /// Straight to the limbs: this is on `RationalType.init(_:_:)`'s path, which
    /// every `BigRat` operation goes through, so the two intermediate `BigUInt`s
    /// the obvious spelling would build are worth skipping.
    public func greatestCommonDivisor(with other: BigInt) -> BigInt {
        // Two magnitudes in one limb each -- every `Int`-sized pair -- run in
        // registers, with one allocation for the answer and none for the working
        // values.
        if let x = self.singleLimbMagnitude, let y = other.singleLimbMagnitude {
            let g = _gcdLimb(x, y)
            return g == 0 ? BigInt() : BigInt(magnitude: [g], negative: false)
        }
        return BigInt(magnitude: _gcd(self.magnitudeLimbs, other.magnitudeLimbs),
                      negative: false)
    }
}

// MARK: bitwise and shifts
//
// All six read straight off the two's complement limbs -- the point of storing
// them that way.

extension BigInt {
    public static func & (lhs: BigInt, rhs: BigInt) -> BigInt {
        let n = Swift.max(lhs.limbs.count, rhs.limbs.count)
        return BigInt(limbs: (0 ..< n).map { lhs.limb($0) & rhs.limb($0) })
    }
    public static func | (lhs: BigInt, rhs: BigInt) -> BigInt {
        let n = Swift.max(lhs.limbs.count, rhs.limbs.count)
        return BigInt(limbs: (0 ..< n).map { lhs.limb($0) | rhs.limb($0) })
    }
    public static func ^ (lhs: BigInt, rhs: BigInt) -> BigInt {
        let n = Swift.max(lhs.limbs.count, rhs.limbs.count)
        return BigInt(limbs: (0 ..< n).map { lhs.limb($0) ^ rhs.limb($0) })
    }
    /// `~x == -x - 1`, which is what two's complement gives without being asked.
    public static prefix func ~ (x: BigInt) -> BigInt {
        return BigInt(limbs: x.limbs.isEmpty ? [UInt.max] : x.limbs.map { ~$0 })
    }
    public static func &= (lhs: inout BigInt, rhs: BigInt) { lhs = lhs & rhs }
    public static func |= (lhs: inout BigInt, rhs: BigInt) { lhs = lhs | rhs }
    public static func ^= (lhs: inout BigInt, rhs: BigInt) { lhs = lhs ^ rhs }

    public static func << <RHS: BinaryInteger>(lhs: BigInt, rhs: RHS) -> BigInt {
        if rhs < 0 { return lhs >> (0 - rhs) }
        if lhs.limbs.isEmpty || rhs == 0 { return lhs }
        return BigInt(limbs: _shiftLeft(lhs.limbs, signExtension: lhs.signExtension, Int(rhs)))
    }
    /// Arithmetic, i.e. flooring: `-5 >> 1` is -3, and shifting a negative value
    /// far enough right leaves -1 rather than 0.
    public static func >> <RHS: BinaryInteger>(lhs: BigInt, rhs: RHS) -> BigInt {
        if rhs < 0 { return lhs << (0 - rhs) }
        if lhs.limbs.isEmpty || rhs == 0 { return lhs }
        guard let k = Int(exactly: rhs), k < lhs.limbs.count * UInt.bitWidth else {
            return BigInt(limbs: [lhs.signExtension])
        }
        return BigInt(limbs: _shiftRight(lhs.limbs, signExtension: lhs.signExtension, k))
    }
    public static func <<= <RHS: BinaryInteger>(lhs: inout BigInt, rhs: RHS) { lhs = lhs << rhs }
    public static func >>= <RHS: BinaryInteger>(lhs: inout BigInt, rhs: RHS) { lhs = lhs >> rhs }
}

// MARK: Strideable

extension BigInt : Strideable {
    public func distance(to other: BigInt) -> BigInt { return other - self }
    public func advanced(by n: BigInt) -> BigInt     { return self + n }
}

// MARK: Double

extension Double {
    public init(_ v: BigInt) {
        let d = Double(v.magnitude)
        self = v.isNegative ? -d : d
    }
}

extension String {
    public init(_ v: BigInt, radix: Int = 10, uppercase: Bool = false) {
        self = v.toString(radix: radix, uppercase: uppercase)
    }
}
