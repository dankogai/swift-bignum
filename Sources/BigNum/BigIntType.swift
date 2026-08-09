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
    /// `self` raised to `exponent`, reduced modulo `modulus` -- Python's
    /// three-argument `pow()`.
    func power(_ exponent: Int, mod modulus: Self) -> Self
    /// The same, for an exponent too wide to be an `Int`.
    func power(_ exponent: Self, mod modulus: Self) -> Self
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
    /// Square-and-multiply, shared by every `power`.  With a `modulus` each
    /// intermediate is reduced as it is formed, so nothing grows past twice the
    /// modulus's width; without one the products run free.
    ///
    /// `exponent` is generic so a modular exponent can be a big integer while an
    /// ordinary one stays an `Int`, and it is taken non-negative -- the callers
    /// have dealt with the sign already.  `modulus`, when given, must be
    /// positive, and `self` must already be reduced into `0 ..< modulus`.
    internal func _squareAndMultiply<E:BinaryInteger>(_ exponent: E, mod modulus: Self?) -> Self {
        var result = Self(1)
        // 1 is not reduced when the modulus is 1, and an exponent of 0 returns
        // it untouched -- so reduce up front rather than special-casing that.
        if let m = modulus { result %= m }
        var (base, n) = (self, exponent)
        while n > 0 {
            if n & 1 == 1 {
                result *= base
                if let m = modulus { result %= m }
            }
            n >>= 1
            if n > 0 {
                base *= base
                if let m = modulus { base %= m }
            }
        }
        return result
    }

    /// A negative `exponent` has no integral answer, so it yields 0 except for
    /// the two values that are their own reciprocal.
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
        return self._squareAndMultiply(UInt(exponent), mod: nil)
    }

    /// `self`⁻¹ mod `modulus` by the extended Euclidean algorithm, or nil when
    /// the two are not coprime and no inverse exists.  `modulus` must be
    /// positive and `self` reduced into `0 ..< modulus`.
    ///
    /// The Bézout coefficient is carried reduced modulo `modulus` rather than as
    /// the signed value the textbook tracks, which keeps every intermediate
    /// non-negative -- an unsigned `Self` could not hold the signed form.
    internal func _inverse(mod modulus: Self) -> Self? {
        var (r, nextR) = (self, modulus)
        var (s, nextS) = (Self(1) % modulus, Self(0))    // self * s ≡ r (mod modulus)
        while !nextR.isZero {
            let q = r / nextR
            (r, nextR) = (nextR, r - q * nextR)
            let qs = ((q % modulus) * nextS) % modulus
            (s, nextS) = (nextS, s >= qs ? s - qs : s + modulus - qs)
        }
        return r == 1 ? s : nil
    }

    /// `self` raised to `exponent`, reduced modulo `modulus` -- Python's
    /// three-argument `pow()`, with the same three conventions:
    ///
    /// * The result carries the **sign of `modulus`**, so it lands in
    ///   `0 ..< modulus` for a positive one.  That is a floored remainder, not
    ///   the truncated one `%` gives: `BigInt(-2).power(3, mod:5)` is 2, where
    ///   `BigInt(-2).power(3) % 5` is -3.
    /// * A **negative `exponent`** raises the modular inverse of `self`, so
    ///   `x.power(-1, mod:m)` *is* that inverse.  It traps when `self` and
    ///   `modulus` are not coprime, there being no inverse to return.
    /// * A **zero `modulus`** traps.
    ///
    /// Only the modulus bounds the intermediates, so this stays cheap where
    /// `power(_:)` could not run at all: `e` squarings of a value no wider than
    /// `modulus`, rather than a result with `e * self.bitWidth` bits.
    public func power(_ exponent: Int, mod modulus: Self) -> Self {
        return self._power(exponent, mod: modulus)
    }

    /// `power(_:mod:)` for an exponent too large to be an `Int`, which is the
    /// usual case in cryptography -- an RSA exponent is as wide as its modulus.
    ///
    /// There is deliberately no `power(_: Self)` to match: without a modulus an
    /// exponent past `Int` has no representable answer anyway, since the result
    /// would need more bits than the machine has.
    public func power(_ exponent: Self, mod modulus: Self) -> Self {
        return self._power(exponent, mod: modulus)
    }

    /// The two `power(_:mod:)`s, differing only in how wide an exponent they let
    /// you write.
    internal func _power<E:BinaryInteger>(_ exponent: E, mod modulus: Self) -> Self {
        precondition(!modulus.isZero, "power(_:mod:) with a modulus of zero")
        // Work in |modulus| throughout and put the sign back at the end.  The
        // `< 0` tests all fold away for an unsigned `Self`, which could not
        // evaluate `0 - modulus` anyway.
        let m = modulus < 0 ? 0 - modulus : modulus
        var base = self % m
        if base < 0 { base += m }
        if exponent < 0 {
            guard let inverse = base._inverse(mod: m) else {
                preconditionFailure("\(self) has no inverse modulo \(modulus)")
            }
            base = inverse
        }
        var result = base._squareAndMultiply(exponent.magnitude, mod: m)
        if modulus < 0 && !result.isZero { result -= m }
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
