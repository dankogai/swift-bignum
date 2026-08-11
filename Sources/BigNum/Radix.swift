//
//  Radix.swift -- text in and text out, without the arithmetic it does not need.
//
//  The generic versions in BigIntType.swift work for any conformer and are what
//  a new type gets for free.  They also treat every radix the same way: peel off
//  the largest chunk of digits that fits a limb, and multiply or divide the whole
//  number by that chunk's base.  For radix 10 that is unavoidable.  For radix 16
//  it is entirely unnecessary -- 16 is a power of two, so each digit *is* four
//  bits of a limb and the conversion is bit shuffling.
//
//  Benchmarking made the cost visible.  Parsing 4096 bits of hex cost 61.5µs
//  against Node's 1.08µs and CPython's 1.29µs, and the giveaway was internal:
//  our hex parse cost the same as our *decimal* parse, when decimal has to do
//  arithmetic and hex does not.  So:
//
//   *  Radix 2, 4, 8, 16 and 32 go through `_limbsFromDigits` and
//      `_digitsFromLimbs`, which touch each digit once and never multiply.
//   *  Every other radix keeps the chunked algorithm, but runs it on the limbs
//      in place, so a parse is one allocation rather than one per chunk.
//
//  Both live here as concrete implementations on `BigUInt` and `BigInt`, which
//  take precedence over the generic ones.  Nothing about the protocol changes.
//

// MARK: - digit tables

private let _lowerDigits = Array("0123456789abcdefghijklmnopqrstuvwxyz".utf8)
private let _upperDigits = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".utf8)

/// How many bits one digit of `radix` is worth, when the answer is a whole
/// number of bits.  Nil for every other radix, which is what selects the
/// arithmetic path.
@inline(__always) internal func _bitsPerDigit(_ radix: Int) -> Int? {
    switch radix {
    case 2:  return 1
    case 4:  return 2
    case 8:  return 3
    case 16: return 4
    case 32: return 5
    default: return nil
    }
}

// MARK: - power-of-two radices, which are pure bit shuffling

/// Fills limbs straight from the digits, least significant first.  `bits` need
/// not divide the limb width: a digit that straddles a limb boundary has its low
/// part written and its high part carried into the next limb.
internal func _limbsFromDigits(_ chars: [UInt8], radix: Int, bits: Int) -> [UInt]? {
    var limbs = [UInt]()
    limbs.reserveCapacity((chars.count * bits) / UInt.bitWidth + 1)
    var acc: UInt = 0
    var used = 0
    var i = chars.count - 1
    while 0 <= i {
        guard let d = _digitValue(chars[i]), d < radix else { return nil }
        let v = UInt(d)
        acc |= v << used
        used += bits
        if used >= UInt.bitWidth {
            limbs.append(acc)
            used -= UInt.bitWidth
            // whatever of this digit did not fit starts the next limb
            acc = used > 0 ? v >> (bits - used) : 0
        }
        i -= 1
    }
    if acc != 0 { limbs.append(acc) }
    _normalize(&limbs)
    return limbs
}

/// And back out.  Each digit is `bits` bits at a known offset, so this reads
/// them off with shifts and never divides.
internal func _digitsFromLimbs(_ limbs: [UInt], radix: Int, bits: Int,
                               uppercase: Bool) -> String {
    guard let top = limbs.last else { return "0" }
    let significant = (limbs.count - 1) * UInt.bitWidth
                        + (UInt.bitWidth - top.leadingZeroBitCount)
    let count = (significant + bits - 1) / bits
    let table = uppercase ? _upperDigits : _lowerDigits
    let mask = UInt(radix - 1)
    var out = [UInt8](repeating: 0, count: count)
    for k in 0 ..< count {
        let offset = k * bits
        let index = offset / UInt.bitWidth
        let shift = offset % UInt.bitWidth
        var v = limbs[index] >> shift
        // a digit that straddles the boundary takes its high bits from above
        if shift + bits > UInt.bitWidth && index + 1 < limbs.count {
            v |= limbs[index + 1] << (UInt.bitWidth - shift)
        }
        out[count - 1 - k] = table[Int(v & mask)]
    }
    return String(decoding: out, as: UTF8.self)
}

// MARK: - every other radix, chunked but in place

/// The chunked parse, with the multiply-and-add done on the limbs rather than
/// through `*` and `+` on the whole type.  Same algorithm as the generic
/// version; one allocation instead of three per chunk.
internal func _limbsFromChunkedDigits(_ chars: [UInt8], radix: Int) -> [UInt]? {
    let (digits, base) = _radixChunk(radix)
    var limbs = [UInt]()
    limbs.reserveCapacity(chars.count / digits + 2)
    // Take the short chunk first so every later one is exactly `digits` wide.
    var i = 0
    var head = chars.count % digits
    if head == 0 { head = digits }
    while i < chars.count {
        let n = i == 0 ? head : digits
        var chunk: UInt = 0
        for _ in 0 ..< n {
            guard let d = _digitValue(chars[i]), d < radix else { return nil }
            chunk = chunk * UInt(radix) + UInt(d)
            i += 1
        }
        if limbs.isEmpty {
            if chunk != 0 { limbs.append(chunk) }
        } else {
            _multiplyInPlace(&limbs, byLimb: base, adding: chunk)
        }
    }
    return limbs
}

/// The chunked render, dividing the limbs in place instead of building a new
/// value per chunk, and writing digits into one byte buffer instead of building
/// and concatenating a `String` per chunk.
internal func _chunkedDigitsFromLimbs(_ limbs: [UInt], radix: Int,
                                      uppercase: Bool) -> String {
    if limbs.isEmpty { return "0" }
    let (digits, base) = _radixChunk(radix)
    var v = limbs
    var chunks = [UInt]()
    chunks.reserveCapacity(limbs.count * 2)
    while !v.isEmpty {
        chunks.append(_divideInPlace(&v, byLimb: base))
    }
    let table = uppercase ? _upperDigits : _lowerDigits
    let r = UInt(radix)
    // Every chunk but the most significant is exactly `digits` wide, zeros
    // included, so the total length is known before a byte is written.
    let top = chunks[chunks.count - 1]
    var topLength = 0
    var t = top
    while t != 0 { topLength += 1 ; t /= r }
    if topLength == 0 { topLength = 1 }
    var out = [UInt8](repeating: table[0], count: topLength + (chunks.count - 1) * digits)
    var pos = out.count - 1
    // Radix 10 gets its own copy of the loop purely so that the divisor is a
    // literal: the compiler turns `% 10` and `/ 10` into a multiply and a shift,
    // where a runtime `r` has to be a real division on every digit.  `description`
    // is the most-called conversion in the package, so it earns the duplication.
    if radix == 10 {
        for k in 0 ..< chunks.count - 1 {
            var x = chunks[k]
            for _ in 0 ..< digits {
                out[pos] = table[Int(x % 10)]
                x /= 10
                pos -= 1
            }
        }
        var x = top
        while x != 0 {
            out[pos] = table[Int(x % 10)]
            x /= 10
            pos -= 1
        }
    } else {
        for k in 0 ..< chunks.count - 1 {
            var x = chunks[k]
            for _ in 0 ..< digits {
                out[pos] = table[Int(x % r)]
                x /= r
                pos -= 1
            }
        }
        var x = top
        while x != 0 {
            out[pos] = table[Int(x % r)]
            x /= r
            pos -= 1
        }
    }
    return String(decoding: out, as: UTF8.self)
}

// MARK: - the text, before any of that

/// Strips the sign and hands back the digits as bytes.  Nil if the text is not
/// a number at all; the digits themselves are validated during conversion.
@inline(__always)
internal func _splitSign<S:StringProtocol>(_ text: S) -> (digits: [UInt8], negative: Bool)? {
    var bytes = Array(text.utf8)
    var negative = false
    if let first = bytes.first {
        if first == UInt8(ascii: "-") { negative = true ; bytes.removeFirst() }
        else if first == UInt8(ascii: "+") { bytes.removeFirst() }
    }
    return bytes.isEmpty ? nil : (bytes, negative)
}

@inline(__always) internal func _digitValue(_ c: UInt8) -> Int? {
    switch c {
    case 0x30 ... 0x39: return Int(c - 0x30)        // 0-9
    case 0x41 ... 0x5A: return Int(c - 0x41) + 10   // A-Z
    case 0x61 ... 0x7A: return Int(c - 0x61) + 10   // a-z
    default:            return nil
    }
}

/// Digits to limbs, by whichever of the two routes the radix allows.
internal func _limbs<S:StringProtocol>(from text: S, radix: Int) -> (limbs: [UInt], negative: Bool)? {
    precondition(2 <= radix && radix <= 36, "radix must be in 2...36, not \(radix)")
    guard let (digits, negative) = _splitSign(text) else { return nil }
    let limbs = _bitsPerDigit(radix).map { _limbsFromDigits(digits, radix: radix, bits: $0) }
                  ?? _limbsFromChunkedDigits(digits, radix: radix)
    guard let l = limbs else { return nil }
    return (l, negative)
}

/// Limbs to digits, likewise.  `limbs` is an unsigned magnitude.
internal func _string(fromMagnitude limbs: [UInt], radix: Int, uppercase: Bool) -> String {
    precondition(2 <= radix && radix <= 36, "radix must be in 2...36, not \(radix)")
    if limbs.isEmpty { return "0" }
    if let bits = _bitsPerDigit(radix) {
        return _digitsFromLimbs(limbs, radix: radix, bits: bits, uppercase: uppercase)
    }
    return _chunkedDigitsFromLimbs(limbs, radix: radix, uppercase: uppercase)
}

// MARK: - and the two concrete types

extension BigUInt {
    public init?<S:StringProtocol>(_ text: S, radix: Int = 10) {
        guard let (limbs, negative) = _limbs(from: text, radix: radix) else { return nil }
        if negative { return nil }          // an unsigned type refuses a sign
        self.init(normalized: limbs)
    }
    public init?(_ description: String) {
        self.init(description, radix: 10)
    }
    public func toString(radix: Int = 10, uppercase: Bool = false) -> String {
        return _string(fromMagnitude: self.limbs, radix: radix, uppercase: uppercase)
    }
    public var description: String {
        return self.toString(radix: 10, uppercase: false)
    }
}

extension BigInt {
    public init?<S:StringProtocol>(_ text: S, radix: Int = 10) {
        guard let (limbs, negative) = _limbs(from: text, radix: radix) else { return nil }
        self.init(magnitude: limbs, negative: negative)
    }
    public init?(_ description: String) {
        self.init(description, radix: 10)
    }
    public func toString(radix: Int = 10, uppercase: Bool = false) -> String {
        let body = _string(fromMagnitude: self.magnitudeLimbs, radix: radix, uppercase: uppercase)
        return isNegative ? "-" + body : body
    }
    public var description: String {
        return self.toString(radix: 10, uppercase: false)
    }
}
