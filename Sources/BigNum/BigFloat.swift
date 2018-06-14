/// conforming to BigFloatingPoint
public struct BigFloat: Equatable, Hashable {  // automatic conformance to Equatable but needs to be overridden
    public typealias IntegerLiteralType = Int
    public typealias FloatLiteralType   = Double
    public typealias Exponent           = Int
    public typealias Significand        = BigInt
    public typealias RawExponent        = UInt
    public typealias RawSignificand     = BigUInt
    public typealias Stride             = BigFloat
    public var scale:Exponent           // stored property
    public var mantissa:Significand     // stored property
    public static var defaultPrecision = 64
    public static var maxExponent =  Int.max
}
// override == to introduce NaN
extension BigFloat {
    public static var nan:BigFloat {
        return BigFloat(scale:Int.max, mantissa:+1)
    }
    public var isNaN:Bool {
        return Swift.abs(scale) == Int.max && mantissa == +1
    }
    public static var signalingNaN:BigFloat {
        return BigFloat(scale:Int.max, mantissa:-1)
    }
    public var isSignalingNaN:Bool {
        return Swift.abs(scale) == Int.max && mantissa == -1
    }
    public static var infinity:BigFloat {
        return BigFloat(scale:Int.max, mantissa:0)
    }
    public var isInfinite:Bool {
        return Swift.abs(self.scale) == Int.max && mantissa == 0
    }
    public static var zero:BigFloat         { return BigFloat(scale:0, mantissa:0) }
    public static var negativeZero:BigFloat { return BigFloat(scale:-Int.max-1, mantissa:0) }
    public var isZero:Bool {
        return  mantissa == 0 && Swift.abs(scale) != Int.max
    }
    public var sign: FloatingPointSign {
        return 0 < mantissa ? .plus
            :  mantissa < 0 ? .minus
            :    scale  < 0 ? .minus : .plus    // ±0 and inifinity
    }
    public mutating func negate() {
        if Swift.abs(scale) == Int.max {
            scale.negate()
        }
        else if mantissa == 0 {
            scale = scale &+ (-Int.max-1)
        }
        else {
            mantissa.negate()
        }
    }
    public static prefix func -(_ bf:BigFloat)->BigFloat {
        var result = bf
        result.negate()
        return result
    }
    public static prefix func +(_ bf:BigFloat)->BigFloat {
        return bf
    }
    public var exponent:Exponent {
        return scale - (mantissa.bitWidth-1)
    }
    public var significand:BigFloat {
        return BigFloat(scale: self.scale - (mantissa.bitWidth + 2), mantissa:self.mantissa)
    }
    public var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:BigFloat) {
        return (sign:sign, exponent:exponent, significand:significand)
    }
    public init(sign:FloatingPointSign, exponent:Exponent, significand:BigFloat) {
        scale    = exponent + significand.scale - (significand.mantissa.bitWidth-1)
        mantissa = sign == .minus ? -significand.mantissa : +significand.mantissa
    }
}
/// BigFloat -> BinaryFloatingPoint
extension BinaryFloatingPoint {
    public init(_ bf:BigFloat) {
        #if os(iOS) || os(watchOS)
        typealias F = Double
        #else
        typealias F = Float80
        #endif
        let offset = Swift.max(bf.mantissa.bitWidth-1 - (Self.significandBitCount+1), 0)
        self.init(
            sign:bf.sign,
            exponent:Exponent(bf.scale - offset),
            significand:Self(F(bf.mantissa.magnitude >> offset))
        )
    }
}
/// BigFloat -> Double
extension Double {
    public init(_ bf:BigFloat) { // tailored becaused it is the most frequently used
        let offset = Swift.max(bf.mantissa.bitWidth-1 - 64, 0)
        self.init(
            sign:bf.sign,
            exponent:Exponent(bf.scale - offset),
            significand:Double(bf.mantissa.magnitude >> offset)
        )
    }
}
/// BigFloat -> BigRat
extension BigRat {
    public init(_ bf:BigFloat) {
        (num, den) = (bf.mantissa, 1)
        if bf.scale < 0 {
            den <<= -bf.scale
        } else {
            num <<= +bf.scale
        }
    }
}
/// init from others
extension BigFloat : ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    public init?<T:BinaryInteger>(exactly bi:T) {
        mantissa = Significand(bi)
        scale = mantissa.bitWidth-1
    }
    /// BinaryInteger -> BigFloat
    public init<T:BinaryInteger>(_ bi:T) { self.init(exactly:bi)! }
    public init(integerLiteral value: Int) { self.init(value) }
    /// BinaryFloatingPoint -> BigFloat
    public init?<T:BinaryFloatingPoint>(exactly bf:T) {
        mantissa = Significand(bf.significandBitPattern | 1 << T.significandBitCount)
        mantissa >>= mantissa.trailingZeroBitCount
        if bf < 0 { mantissa.negate() }
        scale = Exponent(bf.exponent) - (mantissa.bitWidth-1 - 1)
    }
    public init<T:BinaryFloatingPoint>(_ bf:T) { self.init(exactly:bf)! }
    public var asDouble:Double { return Double(self) }
    public init(floatLiteral value: Double) { self.init(value) }
    /// RationalType -> BigFloat
    public init<T:RationalType>(_ q:T, precision px:Int = defaultPrecision) {
        let bits = Swift.min(q.den.bitWidth-1, Swift.abs(px))
        mantissa = Significand(q.num << bits / q.den)
        mantissa >>= mantissa.trailingZeroBitCount
        scale = (q.num.bitWidth-1) - (q.den.bitWidth-1) - (mantissa.bitWidth-1) + 1
    }
}



//    public init(_ bq:BigRat, precision px:Int = defaultPrecision) {
//        if bq.isNaN         { self = BigFloat.nan }
//        if bq.isZero        { self = BigFloat.zero;     if bq.sign == .minus { negate() } }
//        if bq.isInfinite    { self = BigFloat.infinity; if bq.sign == .minus { negate() } }
//
//        let s = max(den.bitWidth - 1, w)    // -1 for sign bit
//        let d = Element(1) << s
//        let t = s - w
//        let n = (num * d / den) >> t    // shift to discard lower bits
//        self = Self(n << t, d)          // and shift back
//
//        self.init(sign:bq.sign, exponent:Exponent(bq.exponent), significand:BigFloat)
//    }

extension BigFloat {
    public var asBigRat:BigRat {
        if isNaN        { return BigRat.nan }
        if isZero       { return (sign == .minus ? -1 : +1) * BigRat.zero }
        if isInfinite   { return (sign == .minus ? -1 : +1) * BigRat.infinity }
        let shift = scale - (mantissa.bitWidth - 2)
        let factor = BigInt(1) << shift.magnitude
        return shift < 0 ? BigRat(mantissa) / factor : BigRat(mantissa) * factor
    }
//    public func toString(radix:Int = 10)->String {
//        if self.isNaN {
//            return "nan"
//        }
//        if self.isInfinite {
//            return (sign == .minus ? "-" : "+") + "infinity"
//        }
//        let (iself, fself) = self.asMixed
//        let sint = String(iself.magnitude, radix:radix)
//        let ilen = sint.count
//        if fself.isZero { return sint + ".0" }
//        let bitsPerDigit = Double.log2(Double(radix))
//        let bitWidth = Swift.max(fself.num.bitWidth, fself.den.bitWidth, Int64.bitWidth)
//        let ndigits = Int(Double(bitWidth) / bitsPerDigit) + 1
//        var (i, r) = (self * BigInt(radix).power(ndigits)).asMixed
//        if 1 <= r.magnitude * 2 {
//            i += i.sign == .minus ? -1 : +1
//        }
//        var s = String(i.magnitude, radix:radix)
//
//        if self.magnitude < 1 {
//            s = [String](repeating:"0", count: ndigits - s.count + 1).joined() + s
//        }
//        s.insert(".", at:s.index(s.startIndex, offsetBy:ilen))
//        while s.last == "0" { s.removeLast() }
//        if s.last == "." { s.append("0") }
//        return (self.sign == .minus ? "-" : "+") + s;
//    }
}


// override == to introduce NaN
extension BigFloat {
    public func isEqual(to other:BigFloat)->Bool {
        return !self.isNaN && !other.isNaN
            && self.scale == other.scale
            && self.mantissa == other.mantissa
    }
    public static func ==(_ lhs:BigFloat, _ rhs:BigFloat)->Bool {
        return lhs.isEqual(to:rhs)
    }
}
/// comparison.  Now we need infinity and isInfinite
extension BigFloat : Comparable {
    

    public static func +(_ lhs:BigFloat, _ rhs:BigFloat)->BigFloat {
        return nan
    }
    
    public func isLess(than other:BigFloat)->Bool {
        if self.isNaN  { return false }
        if other.isNaN { return false }
        if self.isInfinite { }
        fatalError()
    }
    public static func <(_ lhs:BigFloat, _ rhs:BigFloat)->Bool {
        return lhs.isLess(than:rhs)
    }
}
