/// conforming to BigFloatingPoint
public struct BigFloat: Equatable, Hashable, Codable {  // automatic conformance to Equatable but needs to be overridden
    public typealias IntegerLiteralType = Int
    public typealias FloatLiteralType   = Double
    public typealias Exponent           = Int
    public typealias Significand        = BigInt
    public typealias Magnitude          = BigFloat
    public typealias RawExponent        = UInt
    public typealias RawSignificand     = BigUInt
    public typealias Stride             = BigFloat
    public var scale:Exponent           // stored property
    public var mantissa:Significand     // stored property
    public static var precision = 64
    public static var roundingRule = FloatingPointRoundingRule.toNearestOrAwayFromZero
    public static var expLimit     = Self(Int16.max)
    // basic init
    public init(scale: Exponent, mantissa:Significand) {
        let shift = mantissa.trailingZeroBitCount
        self.scale    =    scale  + shift
        self.mantissa = mantissa >> shift
    }
    public init(_ other:Self) {
        self.scale    = other.scale
        self.mantissa = other.mantissa
    }
}
// override == to introduce NaN
extension BigFloat {
    public static var nan:BigFloat {
        return BigFloat(scale:Int.max, mantissa:+1)
    }
    public var isNaN:Bool {
        return scale != -Int.max-1 && Swift.abs(scale) == Int.max && mantissa == +1
    }
    public static var signalingNaN:BigFloat {
        return BigFloat(scale:Int.max, mantissa:-1)
    }
    public var isSignalingNaN:Bool {
        return scale != -Int.max-1 && Swift.abs(scale) == Int.max && mantissa == -1
    }
    public static var infinity:BigFloat {
        return BigFloat(scale:Int.max, mantissa:0)
    }
    public var isInfinite:Bool {
        return scale != -Int.max-1 && Swift.abs(self.scale) == Int.max && mantissa == 0
    }
    public var isFinite: Bool    { return !isNaN && !isInfinite }
    public static var zero:BigFloat         { return BigFloat(scale:0, mantissa:0) }
    public static var negativeZero:BigFloat { return BigFloat(scale:-Int.max-1, mantissa:0) }
    public var isZero:Bool {
        return  mantissa == 0 && scale == 0 || scale == -Int.max-1
    }
    public var isNormal: Bool { return true }       // always
    public var isSubnormal: Bool { return false }   // never
    public var isCanonical: Bool { return true}     // always
    //
    public var sign: FloatingPointSign {
        return 0 < mantissa ? .plus
          :  mantissa < 0 ? .minus
          :    scale  < 0 ? .minus : .plus    // ±0 and inifinity
    }
    public mutating func negate() {
        if scale != -Int.max-1 && Swift.abs(scale) == Int.max {
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
        if self.isNaN || self.isSignalingNaN || self.isZero || self.isInfinite { return scale }
        return scale + (mantissa.bitWidth-2)
    }
    public var significand:BigFloat {
        // print("\(#line)", self)
        if self.isNaN || self.isSignalingNaN || self.isZero || self.isInfinite { return self }
        return BigFloat(scale:-(mantissa.bitWidth-2), mantissa:self.mantissa)
    }
    public var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:BigFloat) {
        return (sign:sign, exponent:exponent, significand:significand)
    }
    public init(sign:FloatingPointSign, exponent:Exponent, significand:BigFloat) {
        scale    = exponent + significand.scale - (significand.mantissa.bitWidth-1)
        mantissa = sign == .minus ? -significand.mantissa : +significand.mantissa
        let shift = mantissa.trailingZeroBitCount
        scale     += shift
        mantissa >>= shift
    }
}
/// BigFloat -> BinaryFloatingPoint
extension BinaryFloatingPoint {
    public init(_ bf:BigFloat) {
        if bf.isNaN                 { self = .nan }
        else if bf.isSignalingNaN   { self = .signalingNaN }
        else if bf.isInfinite       { self = bf.sign == .minus ? -.infinity : +.infinity }
        else if bf.isZero           { self = bf.sign == .minus ? -Self(0) : +Self(0) }
        else {
            // with the advent of Apple Silicon which does not support Float80,
            // F is now always Double
            // #if os(iOS) || os(watchOS)
            #if true
            typealias F = Double
            #else
            typealias F = Float80
            #endif
            let offset = Swift.max(bf.mantissa.bitWidth-1 - (Self.significandBitCount+1), 0)
            self.init(
              sign:bf.sign,
              exponent:Exponent(bf.scale + offset),
              significand:Self(F(bf.mantissa.magnitude >> offset))
            )
        }
    }
}
/// BigFloat -> Double
extension Double {
    public init(_ bf:BigFloat) { // tailored becaused it is the most frequently used
        if bf.isNaN                 { self = .nan }
        else if bf.isSignalingNaN   { self = .signalingNaN }
        else if bf.isInfinite       { self = bf.sign == .minus ? -.infinity : +.infinity }
        else if bf.isZero           { self = bf.sign == .minus ? -Double(0) : +Double(0) }
        else {
            let offset = Swift.max(bf.mantissa.bitWidth-1 - 64, 0)
            self.init(
              sign:bf.sign,
              exponent:Exponent(bf.scale + offset),
              significand:Double(bf.mantissa.magnitude >> offset)
            )
        }
    }
}
/// BigFloat -> BigRat
extension BigRat {
    public init(_ bf:BigFloat) {
        if bf.isNaN                 { self = BigRat.nan }
        else if bf.isSignalingNaN   { self = BigRat.signalingNaN }
        else if bf.isInfinite       { self = bf.sign == .minus ? -BigRat.infinity : +.infinity }
        else if bf.isZero           { self = bf.sign == .minus ? -BigRat.zero : +BigRat.zero }
        else {
            (num, den) = (bf.mantissa, 1)
            if bf.scale < 0 {
                den <<= -bf.scale
            } else {
                num <<= +bf.scale
            }
        }
    }
}
/// init from others
extension BigFloat : ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    public init?<T:BinaryInteger>(exactly bi:T) {
        mantissa = Significand(bi)
        scale = 0
        let shift = mantissa.trailingZeroBitCount
        scale     += shift
        mantissa >>= shift
    }
    /// BinaryInteger -> BigFloat
    public init<T:BinaryInteger>(_ bi:T) { self.init(exactly:bi)! }
    public init(integerLiteral value: Int) { self.init(value) }
    /// BinaryFloatingPoint -> BigFloat
    public init?<T:BinaryFloatingPoint>(exactly bf:T) {
        if bf.isNaN                 { self = .nan }
        else if bf.isSignalingNaN   { self = .signalingNaN }
        else if bf.isInfinite       { self = bf.sign == .minus ? -.infinity : +.infinity }
        else if bf.isZero           { self = bf.sign == .minus ? .negativeZero : .zero }
        else {
            mantissa = Significand(bf.significandBitPattern)
            if bf.isNormal { mantissa |= 1 << T.significandBitCount }
            mantissa >>= mantissa.trailingZeroBitCount
            if bf < 0 { mantissa.negate() }
            scale = Exponent(bf.exponent) - (mantissa.bitWidth-1 - 1)
        }
    }
    public init<T:BinaryFloatingPoint>(_ bf:T) { self.init(exactly:bf)! }
    public var asDouble:Double { return Double(self) }
    public init(floatLiteral value: Double) { self.init(value) }
    // implement truncate() here so init(_q:RationalType) can use it
    public mutating func truncate(width:Int, round:FloatingPointRoundingRule=roundingRule) {
        mantissa.truncate(width: width, round: round)
    }
    public func truncated(width:Int, round:FloatingPointRoundingRule=roundingRule)->BigFloat {
        var result = self
        result.truncate(width:width, round:round)
        return result
    }
    // we have truncate, we have round
    public mutating func round(_ rule:FloatingPointRoundingRule=roundingRule) {
        let width = scale + (mantissa.bitWidth-1)
        mantissa.truncate(width: width, round: rule)
        mantissa >>= (mantissa.bitWidth-1) - width
        scale = 0
    }
    public func rounded(_ rule:FloatingPointRoundingRule=roundingRule)->BigFloat {
        var result = self
        result.round(rule)
        return result
    }
    /// RationalType -> BigFloat
    public init<T:RationalType>(_ q:T,
                                precision px:Int = precision,
                                round rule:FloatingPointRoundingRule=roundingRule)
    {
        if      q.isNaN     { self = .nan }
        else if q.isZero    { self = q.sign == .minus ? .negativeZero : .zero }
        else if q.isInfinite{ self = q.sign == .minus ? -.infinity : +.infinity }
        else {
            let w = max(q.num.bitWidth, q.den.bitWidth) - 1
            let qt = BigInt(q.num).over(BigInt(q.den)).truncated(width:w+px, round:rule)
            self = BigFloat(scale:-qt.den.trailingZeroBitCount, mantissa:qt.num)
        }
    }
}
extension BigFloat {
    public var asBigRat:BigRat {
        return BigRat(self)
    }
}
// override == to introduce NaN
extension BigFloat {
    public func isIdentical(to other:BigFloat)->Bool {
        return self.scale == other.scale && self.mantissa == other.mantissa
    }
    public static func ===(_ lhs:BigFloat, _ rhs:BigFloat)->Bool {
        return lhs.isIdentical(to:rhs)
    }
    public func isEqual(to other:BigFloat)->Bool {
        return self.isNaN || other.isNaN ? false
          :  self.isZero ? other.isZero
          :  self.isIdentical(to: other)
    }
    public static func ==(_ lhs:BigFloat, _ rhs:BigFloat)->Bool {
        return lhs.isEqual(to:rhs)
    }
}
/// comparison.  Now we need infinity and isInfinite
extension BigFloat : Comparable {
    public static func +(_ lhs:BigFloat, _ rhs:BigFloat)->BigFloat {
        if lhs.isNaN || rhs.isNaN { return BigFloat.nan }
        if lhs.isZero { return rhs }
        if rhs.isZero { return lhs }
        if lhs.isInfinite && rhs.isInfinite {
            return lhs.sign == rhs.sign ? lhs : .nan
        }
        if lhs.isInfinite { return lhs }
        if rhs.isInfinite { return rhs }
        var (lm, rm) = (lhs.mantissa, rhs.mantissa)
        let ds = lhs.scale - rhs.scale
        if      ds < 0  { rm <<= -ds }
        else if ds > 0  { lm <<= +ds }
        let es = Swift.max(lhs.scale, rhs.scale)
        let m  = lm + rm
        if m == 0 { return lhs.sign == .minus && rhs.sign == .minus ? .negativeZero : .zero }
        return BigFloat(scale:es - Swift.abs(ds), mantissa:m)
    }
    public static func -(_ lhs:BigFloat, _ rhs:BigFloat)->BigFloat {
        return lhs + (-rhs)
    }
    func isLessThan(_ other:BigFloat, onEqual:Bool)->Bool {
        return self.isEqual(to:other) ? onEqual :  (self - other).sign == .minus
    }
    public func isLess(than other:BigFloat)->Bool {
        return self.isLessThan(other, onEqual:false)
    }
    public static func <(_ lhs:BigFloat, _ rhs:BigFloat)->Bool {
        return lhs.isLess(than:rhs)
    }
    public func isLessThanOrEqualTo(_ other:BigFloat)->Bool {
        return self.isLessThan(other, onEqual:true)
    }
    public static func <=(_ lhs:BigFloat, _ rhs:BigFloat)->Bool {
        return lhs.isLessThanOrEqualTo(rhs)
    }
    public func isTotallyOrdered(belowOrEqualTo other: BigFloat) -> Bool {
        return self.isNaN ? other.isNaN
          : self.isZero && other.isZero ? self.sign == .minus || other.sign == .plus
          : self.isLessThanOrEqualTo(other)
    }
}
/// SignedNumeric!
extension BigFloat : SignedNumeric {
    public var magnitude: BigFloat {
        return self.sign == .minus ? -self : +self
    }
    public static func -= (lhs: inout BigFloat, rhs: BigFloat) {
        lhs = lhs - rhs
    }
    public static func += (lhs: inout BigFloat, rhs: BigFloat) {
        lhs = lhs + rhs
    }
    public static func * (lhs: BigFloat, rhs: BigFloat) -> BigFloat {
        if lhs.isNaN || rhs.isNaN { return .nan }
        if lhs.isInfinite   { return rhs.isZero ? .nan : lhs.sign != rhs.sign ? -.infinity : +.infinity }
        if rhs.isInfinite   { return lhs.isZero ? .nan : lhs.sign != rhs.sign ? -.infinity : +.infinity }
        if lhs.isZero       { return rhs.isInfinite ? .nan : lhs.sign != rhs.sign ? -.zero : +.zero     }
        if rhs.isZero       { return lhs.isInfinite ? .nan : lhs.sign != rhs.sign ? -.zero : +.zero     }
        return BigFloat(scale: lhs.scale + rhs.scale, mantissa: lhs.mantissa * rhs.mantissa)
    }
    public static func *= (lhs: inout BigFloat, rhs: BigFloat) {
        lhs = lhs * rhs
    }
}
// now we have + and -.  Let's make it Strideable
extension BigFloat: Strideable {
    public func distance(to other: BigFloat) -> BigFloat {
        return other - self
    }
    public func advanced(by n: BigFloat) -> BigFloat {
        return self + n
    }
}
// now it is FloatingPoint
extension BigFloat : FloatingPoint{
    public func divided(by other:BigFloat,
                        precision px:Int=precision,
                        round rule:FloatingPointRoundingRule=roundingRule)->BigFloat
    {
        // easy!
        return BigFloat(BigRat(self)/BigRat(other), precision:px, round:rule)
    }
    public mutating func divide(by other:BigFloat,
                                precision px:Int=precision,
                                round rule:FloatingPointRoundingRule=roundingRule)
    {
        self = self.divided(by: other, precision:px, round:rule)
    }
    public static func / (lhs: BigFloat, rhs: BigFloat) -> BigFloat {
        return lhs.divided(by:rhs)
    }
    public static func /= (lhs: inout BigFloat, rhs: BigFloat) {
        lhs = lhs / rhs
    }
    public init(signOf: BigFloat, magnitudeOf: BigFloat) {
        self = signOf.sign == .minus ? -magnitudeOf : +magnitudeOf
    }
    public static var radix: Int { return 2 }
    public static var pi: BigFloat { return BigFloat.PI(precision:BigFloat.precision) }
    public static var greatestFiniteMagnitude: BigFloat { return 0 }
    public static var leastNormalMagnitude: BigFloat    { return 0 }
    public static var leastNonzeroMagnitude: BigFloat   { return 0 }
    public var ulp: BigFloat { return 0 }
    public func quotientAndRemainder(dividingBy other: BigFloat,
                                     precision px:Int=precision,
                                     round rule:FloatingPointRoundingRule=roundingRule)
      -> (quotient:BigFloat, remainder:BigFloat) {
        let (q, r) = BigRat(self).quotientAndRemainder(dividingBy: BigRat(other))
        return (quotient:BigFloat(q), remainder:BigFloat(r, precision:px, round:rule))
    }
    public func truncatingRemainder(dividingBy other: BigFloat,
                                    precision px:Int=precision,
                                    round rule:FloatingPointRoundingRule=roundingRule)->BigFloat
    {
        return self.quotientAndRemainder(dividingBy:other, precision:px, round:rule).quotient
    }
    public mutating func formTruncatingRemainder(dividingBy other: BigFloat) {
        self = self.quotientAndRemainder(dividingBy: other).quotient
    }
    public func remainder(dividingBy other: BigFloat,
                          precision px:Int=precision,
                          round rule:FloatingPointRoundingRule=roundingRule)->BigFloat
    {
        return self.quotientAndRemainder(dividingBy:other, precision:px, round:rule).remainder
    }
    public mutating func formRemainder(dividingBy other: BigFloat) {
        self = self.quotientAndRemainder(dividingBy: other).remainder
    }
    public func squareRoot(precision px:Int=precision,
                           round rule:FloatingPointRoundingRule=roundingRule) -> BigFloat
    {
        if self.isNaN || self.isLess(than:0) { return .nan }
        if self.isZero { return self }
        return BigFloat(BigRat(self).squareRoot(precision:px), precision:px, round:rule)
    }
    public func squareRoot(precision px:Int=precision)->BigFloat {
        return self.squareRoot(precision:px, round:BigFloat.roundingRule)
    }
    public mutating func formSquareRoot(precision px:Int=precision,
                                        round rule:FloatingPointRoundingRule=roundingRule)
    {
        self = self.squareRoot(precision:px, round:rule)
    }
    public mutating func formSquareRoot() {
        self = self.squareRoot()
    }
    public mutating func addProduct(_ lhs: BigFloat, _ rhs: BigFloat) {
        self += lhs * rhs
    }
    public var nextUp: BigFloat {
        return self
    }
}
// and finally
extension BigFloat : BigFloatingPoint {
    public typealias IntType = BigInt
    public static var ATAN1 = (precision:0, value:nan)
    public static var E     = (precision:0, value:nan)
    public static var SQRT2 = (precision:0, value:nan)
    public static var LN2   = (precision:0, value:nan)
    public static var LN10  = (precision:0, value:nan)
    public init(_ value: BigRat) {
        self.init(value, precision:BigFloat.precision, round:BigFloat.roundingRule)
    }
    public static func getEpsilon(precision: Int) -> BigFloat {
        return BigFloat(scale:-Swift.abs(precision), mantissa:1)
    }
    public var asMixed: (BigInt, BigFloat) {
        let (i, f) = BigRat(self).asMixed
        return (i, BigFloat(f))
    }
    public static func % (_ lhs: BigFloat, _ rhs: BigFloat) -> BigFloat {
        return lhs.remainder(dividingBy: rhs)
    }
}
// Custom{,Debug}StringConvertible
extension BigFloat: CustomStringConvertible, CustomDebugStringConvertible {
    public func toString(radix:Int = 10)->String {
        return self.toFloatingPointString(radix:radix)
    }
    public var description:String {
        var s = self.toString()
        if s.first == "+" { s.removeFirst() }
        return s
    }
    public var debugDescription:String {
        var s = self.toString(radix:16)
        if self.isNaN || self.isSignalingNaN || self.isInfinite { return s }
        if self.isZero { return s + "p0" }
        var p = 0
        if s.hasPrefix("-0.0") || s.hasPrefix("+0.0") {
            let idx = s.index(s.startIndex, offsetBy: 3)
            while s[idx] == "0" {
                s.remove(at:idx)
                p -= 4
            }
        }
        else {
            while s.hasSuffix("0.0") {
                let idx = s.index(s.endIndex, offsetBy: -3)
                s.remove(at:idx)
                p += 4
            }
        }
        s.insert("x", at: s.index(s.startIndex, offsetBy:1))
        s.insert("0", at: s.index(s.startIndex, offsetBy:1))
        return s + "p\(p)"
    }
    public init?<S:StringProtocol>(_ str:S, radix:Int=10) {
        self = 0
        guard 0 < str.count else { return nil }
        var base   = radix
        var scale  = 0
        var factor = BigFloat(1)
        var signum = +1.0
        var chars = [Character](str.lowercased())
        if      chars[0] == "+" { signum = +1.0 ; chars.removeFirst() }
        else if chars[0] == "-" { signum = -1.0 ; chars.removeFirst() }
        if chars[0] == "0" {
            chars.removeFirst()
            if chars.count < 1 { return }
            switch chars[0] {
            case "x" : base = 16; chars.removeFirst()
            case "o" : base = 8;  chars.removeFirst()
            case "b" : base = 2;  chars.removeFirst()
            default: while chars[0] == "0" { chars.removeFirst() }
            }
        }
        if base == 16 && chars.contains("p") {
            let cs = chars.split(separator:"p").map{ [Character]($0) }
            chars = cs[0]
            scale = Exponent(String(cs[1]))!
        }
        else if base == 10 && chars.contains("e") {
            let cs = chars.split(separator:"e").map{ [Character]($0) }
            chars = cs[0]
            factor = BigFloat(base).power(BigInt(String(cs[1]))!)
        }
        var dlen = 0
        if let i = chars.firstIndex(of:".") {
            dlen = chars.count - i - 1
            chars.remove(at:i)
        }
        guard let n = BigInt(String(chars), radix:base) else { return nil }
        let d = BigInt(base).power(dlen)
        self = signum * factor * BigFloat(scale:scale, mantissa:1) *  BigFloat(n.over(d))
    }
}
extension String {
    init(_ bf:BigFloat, radix:Int=10, uppercase:Bool=false){
        self = uppercase ? bf.toString(radix:radix).uppercased() : bf.toString(radix:radix)
    }
}
