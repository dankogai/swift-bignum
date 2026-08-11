//
//  BigUInt.swift -- an arbitrary-precision unsigned integer.
//
//  Storage is a little-endian array of `UInt` limbs, normalized so the top limb
//  is never zero.  Zero is therefore the empty array, which makes `isZero`,
//  `bitWidth` and comparison fall out for free.
//
//  The limb-level routines are free functions on `[UInt]` rather than methods:
//  `BigInt` reaches for the same multiplication, division and square root by way
//  of its magnitude, and keeping them out of the struct keeps that honest.
//

// MARK: - limb primitives

/// Drops the zero limbs above the most significant set one.
///
/// Indexed rather than written as `while limbs.last == 0 { limbs.removeLast() }`:
/// this is called on every step of `_gcd`, and `last` goes through
/// `BidirectionalCollection` and an `Optional` that only the optimizer removes.
@inline(__always)
internal func _normalize(_ limbs: inout [UInt]) {
    var n = limbs.count
    while 0 < n && limbs[n - 1] == 0 { n -= 1 }
    if n < limbs.count { limbs.removeLast(limbs.count - n) }
}

@inline(__always)
internal func _normalized(_ limbs: [UInt]) -> [UInt] {
    var l = limbs
    _normalize(&l)
    return l
}

/// -1, 0 or +1 as `a` is less than, equal to or greater than `b`.
internal func _compare(_ a: [UInt], _ b: [UInt]) -> Int {
    if a.count != b.count { return a.count < b.count ? -1 : 1 }
    var i = a.count - 1
    while 0 <= i {
        if a[i] != b[i] { return a[i] < b[i] ? -1 : 1 }
        i -= 1
    }
    return 0
}

internal func _add(_ a: [UInt], _ b: [UInt]) -> [UInt] {
    let (long, short) = a.count < b.count ? (b, a) : (a, b)
    var r = [UInt]()
    r.reserveCapacity(long.count + 1)
    var carry = false
    for i in 0 ..< long.count {
        var (s, o1) = (long[i], false)
        if i < short.count { (s, o1) = long[i].addingReportingOverflow(short[i]) }
        var o2 = false
        if carry { (s, o2) = s.addingReportingOverflow(1) }
        r.append(s)
        carry = o1 || o2   // a limb sum cannot overflow twice
    }
    if carry { r.append(1) }
    return r
}

/// `a - b`, which the caller must know is non-negative.
internal func _subtract(_ a: [UInt], _ b: [UInt]) -> [UInt] {
    var r = [UInt]()
    r.reserveCapacity(a.count)
    var borrow = false
    for i in 0 ..< a.count {
        var (d, o1) = (a[i], false)
        if i < b.count { (d, o1) = a[i].subtractingReportingOverflow(b[i]) }
        var o2 = false
        if borrow { (d, o2) = d.subtractingReportingOverflow(1) }
        r.append(d)
        borrow = o1 || o2
    }
    precondition(!borrow && b.count <= a.count, "BigUInt subtraction went negative")
    _normalize(&r)
    return r
}

/// `a -= b`, which the caller must know stays non-negative.  In place, so a loop
/// that subtracts repeatedly does not allocate once per step.
internal func _subtractInPlace(_ a: inout [UInt], _ b: [UInt]) {
    var borrow = false
    for i in 0 ..< a.count {
        var (d, o1) = (a[i], false)
        if i < b.count { (d, o1) = a[i].subtractingReportingOverflow(b[i]) }
        var o2 = false
        if borrow { (d, o2) = d.subtractingReportingOverflow(1) }
        a[i] = d
        borrow = o1 || o2
    }
    precondition(!borrow && b.count <= a.count, "BigUInt subtraction went negative")
    _normalize(&a)
}

internal func _trailingZeros(_ a: [UInt]) -> Int {
    for (i, limb) in a.enumerated() where limb != 0 {
        return i * UInt.bitWidth + limb.trailingZeroBitCount
    }
    return 0
}

internal func _shiftRightInPlace(_ a: inout [UInt], _ k: Int) {
    if k == 0 || a.isEmpty { return }
    let (limbs, bits) = (k / UInt.bitWidth, k % UInt.bitWidth)
    if a.count <= limbs { a.removeAll(keepingCapacity: true) ; return }
    let n = a.count - limbs
    if bits == 0 {
        for i in 0 ..< n { a[i] = a[i + limbs] }
    } else {
        for i in 0 ..< n {
            let high = i + limbs + 1 < a.count
              ? a[i + limbs + 1] << (UInt.bitWidth - bits) : 0
            a[i] = (a[i + limbs] >> bits) | high
        }
    }
    a.removeLast(a.count - n)
    _normalize(&a)
}

/// `a * limb`, in exactly `a.count + 1` limbs -- unnormalized on purpose, since
/// Algorithm D wants a fixed-width window to subtract.
internal func _multiply(_ a: [UInt], byLimb k: UInt) -> [UInt] {
    var r = [UInt](repeating: 0, count: a.count + 1)
    if k == 0 { return r }
    var carry: UInt = 0
    for i in 0 ..< a.count {
        let (high, low) = k.multipliedFullWidth(by: a[i])
        let (s, o) = low.addingReportingOverflow(carry)
        r[i] = s
        // high <= 2^n-2 whenever low can carry, so this cannot overflow
        carry = high &+ (o ? 1 : 0)
    }
    r[a.count] = carry
    return r
}

/// `a = a * k + addend`, in place.  One pass and at most one append, where
/// `_multiply(_:byLimb:)` followed by `_add` would allocate twice -- which is the
/// difference between one allocation and two per digit chunk when parsing.
internal func _multiplyInPlace(_ a: inout [UInt], byLimb k: UInt, adding addend: UInt) {
    if k == 0 {
        a.removeAll(keepingCapacity: true)
        if addend != 0 { a.append(addend) }
        return
    }
    var carry = addend
    for i in 0 ..< a.count {
        let (high, low) = k.multipliedFullWidth(by: a[i])
        let (s, o) = low.addingReportingOverflow(carry)
        a[i] = s
        carry = high &+ (o ? 1 : 0)
    }
    if carry != 0 { a.append(carry) }
}

/// `a /= d`, in place, returning the remainder.  The counterpart of the above,
/// for the loop that peels digit chunks off a value on the way out.
internal func _divideInPlace(_ a: inout [UInt], byLimb d: UInt) -> UInt {
    precondition(d != 0, "division by zero")
    var rem: UInt = 0
    var i = a.count - 1
    while 0 <= i {
        (a[i], rem) = d.dividingFullWidth((high: rem, low: a[i]))
        i -= 1
    }
    _normalize(&a)
    return rem
}

/// Below this many limbs, schoolbook multiplication beats Karatsuba's bookkeeping.
internal let _karatsubaLimit = 40

internal func _multiply(_ a: [UInt], _ b: [UInt]) -> [UInt] {
    if a.isEmpty || b.isEmpty { return [] }
    if a.count == 1 { return _normalized(_multiply(b, byLimb: a[0])) }
    if b.count == 1 { return _normalized(_multiply(a, byLimb: b[0])) }
    if Swift.min(a.count, b.count) >= _karatsubaLimit { return _karatsuba(a, b) }
    var r = [UInt](repeating: 0, count: a.count + b.count)
    for i in 0 ..< a.count {
        let ai = a[i]
        if ai == 0 { continue }
        var carry: UInt = 0
        for j in 0 ..< b.count {
            let (high, low) = ai.multipliedFullWidth(by: b[j])
            // r[i+j] + low + carry never exceeds 2^n-1 once `high` takes its
            // share, so the running carry stays inside one limb
            let (s1, o1) = r[i+j].addingReportingOverflow(low)
            let (s2, o2) = s1.addingReportingOverflow(carry)
            r[i+j] = s2
            carry = high &+ (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
        }
        var k = i + b.count
        while carry != 0 && k < r.count {
            let (s, o) = r[k].addingReportingOverflow(carry)
            r[k] = s
            carry = o ? 1 : 0
            k += 1
        }
    }
    _normalize(&r)
    return r
}

/// Karatsuba, in the form that needs no signed intermediates:
/// `(a₁B + a₀)(b₁B + b₀) = a₁b₁B² + ((a₀+a₁)(b₀+b₁) - a₁b₁ - a₀b₀)B + a₀b₀`.
internal func _karatsuba(_ a: [UInt], _ b: [UInt]) -> [UInt] {
    // Split at half the *shorter* operand so both halves of both sides are
    // non-trivial; splitting at half the longer one degenerates to schoolbook
    // plus overhead when the two differ a lot in size.
    let m = Swift.min(a.count, b.count) / 2
    let a0 = _normalized(Array(a.prefix(m))), a1 = _normalized(Array(a.dropFirst(m)))
    let b0 = _normalized(Array(b.prefix(m))), b1 = _normalized(Array(b.dropFirst(m)))
    let z0 = _multiply(a0, b0)
    let z2 = _multiply(a1, b1)
    let mid = _subtract(_subtract(_multiply(_add(a0, a1), _add(b0, b1)), z0), z2)
    return _add(_add(z0, _shiftLeft(mid, m * UInt.bitWidth)), _shiftLeft(z2, 2 * m * UInt.bitWidth))
}

internal func _shiftLeft(_ a: [UInt], _ k: Int) -> [UInt] {
    if a.isEmpty || k == 0 { return a }
    let (limbs, bits) = (k / UInt.bitWidth, k % UInt.bitWidth)
    var r = [UInt](repeating: 0, count: a.count + limbs + 1)
    if bits == 0 {
        for i in 0 ..< a.count { r[i + limbs] = a[i] }
    } else {
        for i in 0 ..< a.count {
            r[i + limbs]     |= a[i] << bits
            r[i + limbs + 1]  = a[i] >> (UInt.bitWidth - bits)
        }
    }
    _normalize(&r)
    return r
}

/// `a << k` where `a` is two's complement with `ext` above it, so the bits
/// shifted in at the top are sign and not zero.
internal func _shiftLeft(_ a: [UInt], signExtension ext: UInt, _ k: Int) -> [UInt] {
    let (whole, bits) = (k / UInt.bitWidth, k % UInt.bitWidth)
    // A whole number of limbs moves without touching a bit.
    if bits == 0 {
        var r = [UInt](repeating: 0, count: whole)
        r.reserveCapacity(whole + a.count + 1)
        r.append(contentsOf: a)
        r.append(ext)
        return r
    }
    // Otherwise one pass, carrying each limb's displaced top bits into the next.
    // The bounds and the bits == 0 test used to be inside the loop, which cost
    // four branches per limb on the package's second-cheapest operation.
    let inverse = UInt.bitWidth - bits
    var r = [UInt](repeating: 0, count: a.count + whole + 1)
    var carried: UInt = 0
    for i in 0 ..< a.count {
        r[i + whole] = (a[i] << bits) | carried
        carried = a[i] >> inverse
    }
    r[a.count + whole] = (ext << bits) | carried
    return r
}

/// `a >> k`, arithmetically: `ext` fills in from the left.
internal func _shiftRight(_ a: [UInt], signExtension ext: UInt, _ k: Int) -> [UInt] {
    let (whole, bits) = (k / UInt.bitWidth, k % UInt.bitWidth)
    if a.count <= whole { return [ext] }    // everything shifted out: 0 or -1
    let count = a.count - whole
    if bits == 0 { return Array(a[whole ..< a.count]) }
    let inverse = UInt.bitWidth - bits
    var r = [UInt](repeating: 0, count: count)
    for i in 0 ..< count - 1 {
        r[i] = (a[i + whole] >> bits) | (a[i + whole + 1] << inverse)
    }
    // only the last limb reaches past the end, where the sign extension lives
    r[count - 1] = (a[a.count - 1] >> bits) | (ext << inverse)
    return r
}

///
/// Stein's binary GCD on the limbs.
///
/// `BigIntegerType` has a generic version of this, but it is the single hottest
/// thing in the package -- `RationalType.init(_:_:)` reduces every fraction it
/// builds -- and going through `BinaryInteger`'s witnesses there cost an
/// unspecialized call and a fresh array per iteration.  Same algorithm, in place.
///
/// Binary GCD on single words, for the operands that fit in one -- which is
/// every `Int`-sized pair, and is `BigRat`'s hot path since every rational
/// reduces on construction.
internal func _gcdLimb(_ a: UInt, _ b: UInt) -> UInt {
    if a == 0 { return b }
    if b == 0 { return a }
    var (x, y) = (a, b)
    let twos = Swift.min(x.trailingZeroBitCount, y.trailingZeroBitCount)
    x >>= x.trailingZeroBitCount
    y >>= y.trailingZeroBitCount
    while x != y {
        if x < y { swap(&x, &y) }
        x -= y
        x >>= x.trailingZeroBitCount
    }
    return x << twos
}

internal func _gcd(_ a: [UInt], _ b: [UInt]) -> [UInt] {
    if a.isEmpty { return b }
    if b.isEmpty { return a }
    let twos = Swift.min(_trailingZeros(a), _trailingZeros(b))
    var (x, y) = (a, b)
    _shiftRightInPlace(&x, _trailingZeros(x))
    _shiftRightInPlace(&y, _trailingZeros(y))
    // If either odd part is 1, the two share nothing but their factors of two.
    // Worth its own line because it is not a rare case: a denominator that is a
    // power of two lands here every time, and every `truncate(width:)` produces
    // one -- so this is the shape `BigRat` reduces most often.  Without it the loop
    // below takes 1 off the other side and shifts, over and over, which is O(n²)
    // to discover an answer that is already known.  It was most of the time in
    // computing π/4 at 4096 bits.
    if x == [1] || y == [1] { return _shiftLeft([1], twos) }
    // Both odd from here, so every difference is even and the loop shrinks.
    if _compare(x, y) < 0 { swap(&x, &y) }
    while !x.isEmpty {
        _shiftRightInPlace(&x, _trailingZeros(x))
        if _compare(x, y) < 0 { swap(&x, &y) }
        _subtractInPlace(&x, y)
    }
    return _shiftLeft(y, twos)
}

/// The two's complement negation of `a`, limb for limb.  Widen `a` first if the
/// result has to stay the same sign.
internal func _negate(_ a: [UInt]) -> [UInt] {
    var r = [UInt]()
    r.reserveCapacity(a.count)
    var carry = true
    for limb in a {
        let c = ~limb
        if carry {
            let (s, o) = c.addingReportingOverflow(1)
            r.append(s)
            carry = o
        } else {
            r.append(c)
        }
    }
    return r
}

internal func _shiftRight(_ a: [UInt], _ k: Int) -> [UInt] {
    if a.isEmpty || k == 0 { return a }
    let (limbs, bits) = (k / UInt.bitWidth, k % UInt.bitWidth)
    if a.count <= limbs { return [] }
    var r = [UInt](repeating: 0, count: a.count - limbs)
    if bits == 0 {
        for i in 0 ..< r.count { r[i] = a[i + limbs] }
    } else {
        for i in 0 ..< r.count {
            r[i] = a[i + limbs] >> bits
            if i + limbs + 1 < a.count { r[i] |= a[i + limbs + 1] << (UInt.bitWidth - bits) }
        }
    }
    _normalize(&r)
    return r
}

internal func _divide(_ a: [UInt], byLimb d: UInt) -> (quotient: [UInt], remainder: UInt) {
    precondition(d != 0, "division by zero")
    var q = [UInt](repeating: 0, count: a.count)
    var rem: UInt = 0
    var i = a.count - 1
    while 0 <= i {
        // rem < d holds throughout, which is what dividingFullWidth demands
        (q[i], rem) = d.dividingFullWidth((high: rem, low: a[i]))
        i -= 1
    }
    _normalize(&q)
    return (q, rem)
}

///
/// Knuth, TAOCP vol.2 §4.3.1, Algorithm D.
///
internal func _divide(_ a: [UInt], _ b: [UInt]) -> (quotient: [UInt], remainder: [UInt]) {
    precondition(!b.isEmpty, "division by zero")
    if _compare(a, b) < 0 { return ([], a) }
    if b.count == 1 {
        let (q, r) = _divide(a, byLimb: b[0])
        return (q, r == 0 ? [] : [r])
    }
    let n = b.count
    let m = a.count - n
    // D1. Scale both sides until the divisor's top bit is set, which is what
    // makes the quotient estimate in D3 good to within one.
    let shift = b[n-1].leadingZeroBitCount
    let v = _shiftLeft(b, shift)                    // still exactly n limbs
    var u = _shiftLeft(a, shift)
    u.append(contentsOf: repeatElement(0, count: (m + n + 1) - u.count))
    var q = [UInt](repeating: 0, count: m + 1)
    let (vn1, vn2) = (v[n-1], v[n-2])
    var j = m
    while 0 <= j {
        // D3. Estimate one quotient limb from the top two limbs of the
        // remainder, then walk it down with Knuth's 3-by-2 test.
        var qhat: UInt
        var rhat: UInt
        var testable = true
        if vn1 <= u[j+n] {
            // The 2-by-1 estimate would be a limb or more, so clamp it.  This
            // needs `u[j+n] == vn1`, since the running remainder is below the
            // divisor, and then rhat is u[j+n-1] + vn1 -- which may itself spill
            // out of a limb, in which case the 3-by-2 test below cannot fire and
            // the clamp stands.
            qhat = UInt.max
            let (r, overflow) = u[j+n-1].addingReportingOverflow(vn1)
            (rhat, testable) = (r, !overflow)
        } else {
            (qhat, rhat) = vn1.dividingFullWidth((high: u[j+n], low: u[j+n-1]))
        }
        while testable {
            let (high, low) = qhat.multipliedFullWidth(by: vn2)
            if high < rhat || (high == rhat && low <= u[j+n-2]) { break }
            qhat -= 1
            let (next, overflow) = rhat.addingReportingOverflow(vn1)
            if overflow { break }   // rhat past a limb: the test cannot fire again
            rhat = next
        }
        // D4. u[j...j+n] -= qhat * v
        let product = _multiply(v, byLimb: qhat)
        var borrow = false
        for i in 0 ... n {
            var (d, o1) = u[j+i].subtractingReportingOverflow(product[i])
            var o2 = false
            if borrow { (d, o2) = d.subtractingReportingOverflow(1) }
            u[j+i] = d
            borrow = o1 || o2
        }
        // D5/D6. If the window went negative the estimate was too big, so give
        // the divisor back.  Knuth proves one pass is always enough after D3;
        // looping to the fixed point instead costs nothing measurable and makes
        // the result independent of how good the estimate was -- which matters
        // because random inputs reach this branch about once in 2^64 tries, so no
        // test is going to find it if the reasoning is wrong.
        while borrow {
            qhat -= 1
            var carry = false
            for i in 0 ..< n {
                var (s, o1) = u[j+i].addingReportingOverflow(v[i])
                var o2 = false
                if carry { (s, o2) = s.addingReportingOverflow(1) }
                u[j+i] = s
                carry = o1 || o2
            }
            let (top, cleared) = u[j+n].addingReportingOverflow(carry ? 1 : 0)
            u[j+n] = top
            borrow = !cleared   // only a carry out of the top cancels the borrow
        }
        q[j] = qhat
        j -= 1
    }
    _normalize(&q)
    return (q, _shiftRight(_normalized(Array(u.prefix(n))), shift))
}

// MARK: - BigUInt

///
/// An arbitrary-precision unsigned integer.
///
public struct BigUInt : BigUIntType, Hashable {
    public typealias Words = [UInt]
    public typealias Stride = BigInt
    public typealias IntegerLiteralType = UInt64
    public typealias Magnitude = BigUInt

    /// Little-endian base-2^`UInt.bitWidth` limbs; empty is zero and the last
    /// limb, when there is one, is never zero.
    @usableFromInline internal var limbs: [UInt]

    /// Assigns before normalizing, so a caller handing over a uniquely-referenced
    /// array gets the trim in place instead of a copy.
    @usableFromInline internal init(limbs: [UInt]) {
        self.limbs = limbs
        _normalize(&self.limbs)
    }
    /// Skips normalization -- only for callers that already guarantee it.
    @usableFromInline internal init(normalized limbs: [UInt]) {
        self.limbs = limbs
    }
    public init() {
        self.limbs = []
    }
}

extension BigUInt {
    public static var isSigned: Bool { return false }
    public var magnitude: BigUInt    { return self }
    public var words: [UInt]         { return limbs.isEmpty ? [0] : limbs }
    public var isZero: Bool          { return limbs.isEmpty }

    /// The number of significant bits, so zero is 0 bits wide.  Note that this
    /// is *not* a multiple of the limb width; nothing in `BinaryInteger` requires
    /// it to be, and `BigNum` reads it as "the position of the top set bit".
    public var bitWidth: Int {
        guard let top = limbs.last else { return 0 }
        return limbs.count * UInt.bitWidth - top.leadingZeroBitCount
    }
    /// Zero has no set bit to stop at, and reports 0 rather than diverging.
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

extension BigUInt {
    public init(integerLiteral value: UInt64) {
        self.init(value)
    }
    public init<T: BinaryInteger>(_ source: T) {
        precondition(0 <= source, "negative \(T.self) in a BigUInt")
        self.init(limbs: source.words.map { $0 })
    }
    public init?<T: BinaryInteger>(exactly source: T) {
        guard 0 <= source else { return nil }
        self.init(limbs: source.words.map { $0 })
    }
    /// There is no width here to truncate *to*, so this reinterprets the
    /// source's own two's complement words as unsigned: a negative source comes
    /// out as the value its word pattern spells, e.g. `Int(-1)` as 2^64-1.
    public init<T: BinaryInteger>(truncatingIfNeeded source: T) {
        self.init(limbs: source.words.map { $0 })
    }
    public init<T: BinaryInteger>(clamping source: T) {
        self = source < 0 ? BigUInt() : BigUInt(limbs: source.words.map { $0 })
    }
    public init?<T: BinaryFloatingPoint>(exactly source: T) {
        guard source.isFinite, 0 <= source, source == source.rounded(.towardZero) else { return nil }
        if source.isZero { self.init() ; return }
        // value == significand * 2^(exponent - significandBitCount)
        var m = BigUInt(source.significandBitPattern)
        if source.isNormal { m |= BigUInt(1) << T.significandBitCount }
        let shift = Int(source.exponent) - T.significandBitCount
        self = 0 <= shift ? m << shift : m >> -shift
    }
    public init<T: BinaryFloatingPoint>(_ source: T) {
        guard let v = BigUInt(exactly: source.rounded(.towardZero)) else {
            preconditionFailure("\(source) cannot be a BigUInt")
        }
        self = v
    }
}

// MARK: comparison

extension BigUInt : Comparable {
    public static func == (lhs: BigUInt, rhs: BigUInt) -> Bool {
        return lhs.limbs == rhs.limbs
    }
    public static func < (lhs: BigUInt, rhs: BigUInt) -> Bool {
        return _compare(lhs.limbs, rhs.limbs) < 0
    }
}

// MARK: arithmetic

extension BigUInt {
    public static func + (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        return BigUInt(limbs: _add(lhs.limbs, rhs.limbs))
    }
    public static func - (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        return BigUInt(normalized: _subtract(lhs.limbs, rhs.limbs))
    }
    public static func * (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        return BigUInt(normalized: _multiply(lhs.limbs, rhs.limbs))
    }
    public static func / (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        return BigUInt(normalized: _divide(lhs.limbs, rhs.limbs).quotient)
    }
    public static func % (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        return BigUInt(normalized: _divide(lhs.limbs, rhs.limbs).remainder)
    }
    public func quotientAndRemainder(dividingBy other: BigUInt)
      -> (quotient: BigUInt, remainder: BigUInt)
    {
        let (q, r) = _divide(self.limbs, other.limbs)
        return (BigUInt(normalized: q), BigUInt(normalized: r))
    }
    public static func += (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs + rhs }
    public static func -= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs - rhs }
    public static func *= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs * rhs }
    public static func /= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs / rhs }
    public static func %= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs % rhs }
}

// MARK: bitwise and shifts

extension BigUInt {
    public static func & (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        let n = Swift.min(lhs.limbs.count, rhs.limbs.count)
        return BigUInt(limbs: (0 ..< n).map { lhs.limbs[$0] & rhs.limbs[$0] })
    }
    public static func | (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        let n = Swift.max(lhs.limbs.count, rhs.limbs.count)
        return BigUInt(limbs: (0 ..< n).map { lhs.limb($0) | rhs.limb($0) })
    }
    public static func ^ (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        let n = Swift.max(lhs.limbs.count, rhs.limbs.count)
        return BigUInt(limbs: (0 ..< n).map { lhs.limb($0) ^ rhs.limb($0) })
    }
    /// An unsigned value has no width to complement within, so this flips the
    /// bits `self` actually occupies -- `~x == (1 << x.limbWidth) - 1 - x`.
    /// `BigInt` is the type where `~` means what it usually means.
    public static prefix func ~ (x: BigUInt) -> BigUInt {
        return BigUInt(limbs: x.limbs.map { ~$0 })
    }
    @inline(__always) internal func limb(_ i: Int) -> UInt {
        return i < limbs.count ? limbs[i] : 0
    }
    public static func &= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs & rhs }
    public static func |= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs | rhs }
    public static func ^= (lhs: inout BigUInt, rhs: BigUInt) { lhs = lhs ^ rhs }

    public static func << <RHS: BinaryInteger>(lhs: BigUInt, rhs: RHS) -> BigUInt {
        if rhs < 0 { return lhs >> (0 - rhs) }
        return BigUInt(normalized: _shiftLeft(lhs.limbs, Int(rhs)))
    }
    public static func >> <RHS: BinaryInteger>(lhs: BigUInt, rhs: RHS) -> BigUInt {
        if rhs < 0 { return lhs << (0 - rhs) }
        // A shift past the top just empties it, and Int(rhs) could trap first
        guard let k = Int(exactly: rhs), k < lhs.bitWidth else { return BigUInt() }
        return BigUInt(normalized: _shiftRight(lhs.limbs, k))
    }
    public static func <<= <RHS: BinaryInteger>(lhs: inout BigUInt, rhs: RHS) { lhs = lhs << rhs }
    public static func >>= <RHS: BinaryInteger>(lhs: inout BigUInt, rhs: RHS) { lhs = lhs >> rhs }
}

// MARK: Strideable

extension BigUInt : Strideable {
    public func distance(to other: BigUInt) -> BigInt {
        return BigInt(other) - BigInt(self)
    }
    public func advanced(by n: BigInt) -> BigUInt {
        return BigUInt(BigInt(self) + n)
    }
}

// MARK: square root
//
// `BigIntegerType` has a generic Newton iteration, but doing it on the limbs
// saves a `bitWidth` scan and an allocation per step, and this is on BigRat's
// hot path by way of `RationalType.squareRoot(precision:)`.

extension BigUInt {
    public func greatestCommonDivisor(with other: BigUInt) -> BigUInt {
        if limbs.count <= 1 && other.limbs.count <= 1 {
            let g = _gcdLimb(limbs.first ?? 0, other.limbs.first ?? 0)
            return BigUInt(normalized: g == 0 ? [] : [g])
        }
        return BigUInt(normalized: _gcd(self.limbs, other.limbs))
    }

    public func squareRoot() -> BigUInt {
        // One limb is the common case on `Rational`'s path, and it runs entirely
        // in registers.
        if limbs.count <= 1 {
            guard let n = limbs.last, 2 <= n else { return self }
            var x = UInt(1) << ((UInt.bitWidth - n.leadingZeroBitCount + 2) / 2)
            while true {
                let y = (x + n/x) >> 1
                if x <= y { return BigUInt(x) }
                x = y
            }
        }
        var x = BigUInt(normalized: _shiftLeft([1], (bitWidth + 2) / 2))
        while true {
            let y = (x + self/x) >> 1
            if x <= y { return x }
            x = y
        }
    }
}

// MARK: Double

extension Double {
    /// Round-to-nearest-even, overflowing to `+infinity` the way a `Double`
    /// arithmetic operation would.
    public init(_ v: BigUInt) {
        let width = v.bitWidth
        if width == 0  { self = 0 ; return }
        if width <= 53 { self = Double(UInt64(v)) ; return }
        // Keep 54 bits: 53 for the significand and one to round on.
        let shift = width - 54
        let top = UInt64(v >> shift)
        let (significand, roundBit) = (top >> 1, top & 1)
        let sticky = v.trailingZeroBitCount < shift
        let m = roundBit == 1 && (sticky || significand & 1 == 1) ? significand + 1 : significand
        self = Double(sign: .plus, exponent: shift + 1, significand: Double(m))
    }
}

extension String {
    /// Chunked base conversion, which beats the generic `BinaryInteger` overload
    /// by a factor of the digits-per-limb.
    public init(_ v: BigUInt, radix: Int = 10, uppercase: Bool = false) {
        self = v.toString(radix: radix, uppercase: uppercase)
    }
}
