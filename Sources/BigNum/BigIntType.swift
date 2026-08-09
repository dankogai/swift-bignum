//
//  BigIntType.swift -- what an arbitrary-precision integer is, and the parts of
//  one that do not care how its limbs are stored.
//
//  The layering is deliberate.  `BigIntegerType` adds the five operations that
//  `BinaryInteger` does not have but every big integer needs; `BigUIntType` and
//  `BigIntType` then say nothing at all beyond "and it is unsigned" / "and it is
//  signed".  Everything below is written against `BinaryInteger`'s own vocabulary,
//  so `BigUInt` and `BigInt` inherit a working -- if not always the fastest --
//  version of each and only override what is worth specializing.
//

///
/// An integer of arbitrary width.
///
/// The `Codable` and `Sendable` refinements are not decoration: `BigRational`'s
/// synthesized `Codable` needs the former and its `Sendable` conformance needs
/// the latter.
///
public protocol BigIntegerType : BinaryInteger, LosslessStringConvertible, Codable, Sendable {
    /// Whether `self` is zero, without building a zero to compare against.
    var isZero: Bool { get }
    /// `self` written in `radix`, which must be in `2...36`.
    func toString(radix: Int, uppercase: Bool) -> String
    /// Parses `text` in `radix`, which must be in `2...36`.  A leading `+` or
    /// `-` is accepted; `-` only by a signed type.
    init?<S: StringProtocol>(_ text: S, radix: Int)
    /// ⌊√self⌋.  Traps on a negative `self`.
    func squareRoot() -> Self
    /// `self` raised to `exponent`.
    func power(_ exponent: Int) -> Self
    /// The greatest common divisor of `self` and `other`, always non-negative.
    func greatestCommonDivisor(with other: Self) -> Self
}

/// An unsigned integer of arbitrary width.
public protocol BigUIntType : BigIntegerType, UnsignedInteger {}

/// A signed integer of arbitrary width.
public protocol BigIntType : BigIntegerType, SignedInteger where Magnitude : BigUIntType {}

// MARK: - radix conversion

/// The largest power of `radix` that still fits in a single limb, so string
/// conversion can move `digits` digits per bignum division instead of one.
@inline(__always)
internal func _radixChunk(_ radix: Int) -> (digits: Int, base: UInt) {
    precondition(2 <= radix && radix <= 36, "radix must be in 2...36, not \(radix)")
    var (digits, base) = (1, UInt(radix))
    while true {
        let (next, overflow) = base.multipliedReportingOverflow(by: UInt(radix))
        if overflow { break }
        (digits, base) = (digits + 1, next)
    }
    return (digits, base)
}

@inline(__always)
internal func _digitValue(_ c: Character) -> Int? {
    guard let a = c.asciiValue else { return nil }
    switch a {
    case 0x30 ... 0x39: return Int(a - 0x30)        // 0-9
    case 0x41 ... 0x5A: return Int(a - 0x41) + 10   // A-Z
    case 0x61 ... 0x7A: return Int(a - 0x61) + 10   // a-z
    default:            return nil
    }
}

extension BigIntegerType {
    public func toString(radix: Int = 10, uppercase: Bool = false) -> String {
        if self.isZero { return "0" }
        let negative = self < 0
        var v = negative ? 0 - self : self
        let (digits, base) = _radixChunk(radix)
        let chunkBase = Self(base)
        // Peel off `digits` digits per division.  The chunks come out least
        // significant first, and every one but the last needs zero padding.
        var chunks:[UInt] = []
        while !v.isZero {
            let (q, r) = v.quotientAndRemainder(dividingBy: chunkBase)
            chunks.append(UInt(r))
            v = q
        }
        var s = String(chunks.removeLast(), radix: radix, uppercase: uppercase)
        while let c = chunks.popLast() {
            let d = String(c, radix: radix, uppercase: uppercase)
            if d.count < digits { s += String(repeating: "0", count: digits - d.count) }
            s += d
        }
        return negative ? "-" + s : s
    }

    public init?<S: StringProtocol>(_ text: S, radix: Int = 10) {
        var t = text[text.startIndex ..< text.endIndex]
        var negative = false
        if      t.hasPrefix("-") { negative = true ; t = t.dropFirst() }
        else if t.hasPrefix("+") {                   t = t.dropFirst() }
        if negative && !Self.isSigned { return nil }
        guard !t.isEmpty else { return nil }
        let (digits, base) = _radixChunk(radix)
        let chunkBase = Self(base)
        var result = Self(0)
        let chars = Array(t)
        // Take the short chunk first, so every later one is exactly `digits`
        // wide and shifts in with the full `chunkBase` multiplier.  On that
        // first pass `result` is still 0, so the multiply is a no-op.
        var i = 0
        var head = chars.count % digits
        if head == 0 { head = digits }
        while i < chars.count {
            let n = i == 0 ? head : digits
            var chunk:UInt = 0
            for _ in 0 ..< n {
                guard let d = _digitValue(chars[i]), d < radix else { return nil }
                chunk = chunk * UInt(radix) + UInt(d)
                i += 1
            }
            result = result * chunkBase + Self(chunk)
        }
        self = negative ? 0 - result : result
    }

    public var description: String {
        return self.toString(radix: 10, uppercase: false)
    }

    public init?(_ description: String) {
        self.init(description, radix: 10)
    }
}

// MARK: - Codable
//
// A single base-16 string.  Words-plus-sign would encode faster, but this stays
// readable in a JSON dump and cannot be invalidated by a change of limb width.

extension BigIntegerType {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let value = Self(text, radix: 16) else {
            throw DecodingError.dataCorruptedError(
              in: container, debugDescription: "not a base-16 \(Self.self): \"\(text)\"")
        }
        self = value
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.toString(radix: 16, uppercase: false))
    }
}

// MARK: - the arithmetic that only needs BinaryInteger

extension BigIntegerType {
    /// Square-and-multiply.  A negative `exponent` has no integral answer, so it
    /// yields 0 except for the two values that are their own reciprocal.
    public func power(_ exponent: Int) -> Self {
        if exponent == 0 { return 1 }
        if exponent == 1 { return self }
        if exponent < 0 {
            // ±1 are the only integers with an integral reciprocal; the rest
            // round to zero.
            precondition(!self.isZero, "0 raised to a negative power")
            if self == 1 { return 1 }
            if Self.isSigned && self == 0 - 1 { return exponent % 2 == 0 ? 1 : self }
            return 0
        }
        var (result, base, n) = (Self(1), self, exponent)
        while n > 0 {
            if n & 1 == 1 { result *= base }
            n >>= 1
            if n > 0 { base *= base }
        }
        return result
    }

    /// Stein's binary GCD: shifts and subtractions only, no division.
    public func greatestCommonDivisor(with other: Self) -> Self {
        var x = self  < 0 ? 0 - self  : self
        var y = other < 0 ? 0 - other : other
        if x.isZero { return y }
        if y.isZero { return x }
        let twos = Swift.min(x.trailingZeroBitCount, y.trailingZeroBitCount)
        x >>= x.trailingZeroBitCount
        y >>= y.trailingZeroBitCount
        // From here both are odd, so every subtraction produces at least one
        // trailing zero and the loop is guaranteed to shrink.
        if x < y { swap(&x, &y) }
        while !x.isZero {
            x >>= x.trailingZeroBitCount
            if x < y { swap(&x, &y) }
            x -= y
        }
        return y << twos
    }

    /// Newton's method on the integers.  `x` decreases monotonically to
    /// ⌊√self⌋ from an initial guess that is never below it.
    public func squareRoot() -> Self {
        precondition(self >= 0, "square root of a negative \(Self.self)")
        if self < 2 { return self }
        var x = Self(1) << ((self.bitWidth + 2) / 2)
        while true {
            let y = (x + self/x) >> 1
            if y >= x { return x }
            x = y
        }
    }
}
