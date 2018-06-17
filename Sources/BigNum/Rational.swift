/// Signed integer type that can be a numerator and denominator of `RationalType`
public protocol RationalElement : SignedInteger {
    init(_:Int)
}

extension RationalElement {
    /// - returns: the greatest common divisor of `self`
    public func greatestCommonDivisor(with n:Self)->Self {
        if let bi = self as? BigInt {
            return Self(bi.greatestCommonDivisor(with:n as! BigInt))
        }
        // print("\(Self.self).greatestCommonDivisor: slow version")
        var r = self < 0 ? -self : +self
        var q =    n < 0 ?    -n : +n
        if r < q { (r, q) = (q, r) }
        while r > 0 {
            (q, r) = (r, q % r)
        }
        return q
    }
    public func over(_ den:Self)->Rational<Self> {
        return Rational(self, den)
    }
    public func squareRoot()->Self {
        return Self(BigInt(self).squareRoot())
    }
}

extension RationalElement where Self == BigInt {
    public func greatestCommonDivisor(with n:Self)->Self {
         return Self(BigInt(self).greatestCommonDivisor(with:BigInt(n)))
    }
//    public mutating func truncate(width:Int, round:FloatingPointRoundingRule = .toNearestOrAwayFromZero) {
//        let w = Swift.abs(width)
//        if self.bitWidth - 1 < w { return }
//        let t = self.bitWidth - 1 - w
//        let n = BigRat(self >> t).rounded(round).num
//        self = Self(n) << t
//    }
//    public func truncated(width:Int, round:FloatingPointRoundingRule = .toNearestOrAwayFromZero)->Self {
//        var result = self
//        result.truncate(width:width, round:round)
//        return result
//    }
}

/// Rational number type whose numerator and denominator are `RationalElement`
public protocol RationalType : CustomStringConvertible, FloatingPoint, ExpressibleByFloatLiteral {
    associatedtype Element:RationalElement
    associatedtype IntType:RationalElement
    var num:Element { get set }
    var den:Element { get set }
    init(num:Element, den:Element)
    static var maxExponent:Int { get }
}

public protocol BigRationalType : RationalType & BigFloatingPoint {}

extension BigInt: RationalElement {
    public func over(_ den:BigInt)->BigRational {
        return BigRational(self, den)
    }
}

extension BigRationalType {
    /// truncate significand to `width` bits
    public mutating func truncate(width:Int, round:FloatingPointRoundingRule=Self.roundingRule) {
        if self.isNaN || self.isZero || self.isInfinite { return }
        if width == 0       { return }
        let w = width < 0 ? -width : +width
        let s = max(den.bitWidth - 1, w)    // -1 for sign bit
        let d = Element(1) << s
        var n = (num << (s+2)) / den    // 2 bits for rounding hint
        n.truncate(width:width, round:round)
        self = Self(n >> 2, d)  // shift down and back up to discard lower bits
    }
}

extension RationalType {
    public static var radix: Int                    { return 2 }
    public static var nan: Self                     { return Self(num:0, den:0) }
    public static var signalingNaN:Self             { return nan }
    public static var zero:Self                     { return Self(num:0, den:+1) }
    public static var negativeZero:Self             { return Self(num:0, den:-1) }
    public static var infinity:Self                 { return Self(num:+1, den:0) }
    public static var greatestFiniteMagnitude:Self  { return infinity }
    public static var pi:Self                       { return Self(Double.pi) }
    public static var ulp:Self                      { return zero }
    public static var leastNormalMagnitude:Self     { return zero }
    public static var leastNonzeroMagnitude:Self    { return zero }
    public var ulp:Self                             { return Self.zero }
    public var sign:FloatingPointSign   {
        return num != 0
        ? num < 0 ? .minus : .plus
        : den < 0 ? .minus : .plus
    }
    /// decompose to sign, exponent and significand
    /// - sign:        .minus or .plus
    /// - exponent:    exponent in radix 2
    /// - significand: normalized to range  [1, 2)
    public var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:Self) {
        if self.isNaN || self.isInfinite {
            return (sign:self.sign, exponent:Exponent(Int.max), significand:Swift.abs(self))
        }
        if self.isZero {
            return (sign:self.sign, exponent:Exponent(-Int.max), significand:Swift.abs(self))
        }
        // cf. http://blog.livedoor.jp/dankogai/archives/51231722.html
        func msb(of n:Element)->Int {
            if n is BigInt { return n.bitWidth - 2 }    // sign bit and minimum bit
            var u = UInt64(bitPattern: Int64(n < 0 ? -n : +n))
            for i in 0..<UInt64.bitWidth {
                if u == 0 { return i }
                u >>= 1
            }
            return 0
        }
        if Swift.abs(self.den) == 1 {
            let e = msb(of:num)
            return (sign:self.sign, exponent:Exponent(e), significand:Self(num, den << e))
        }
        var e = msb(of:num) - msb(of:den)
        // print("e=", e, msb(of:num), msb(of:den))
        var s = e < 0 ? Self(num << -e, den) : Self(num, den << e)
        if       s.magnitude < 1 { s *= 2 ; e -= 1 } // too small
        else if 2 <= s.magnitude { s /= 2 ; e += 1 } // too large
        return (sign:self.sign, exponent:Exponent(e), significand:Swift.abs(s))
    }
    public var exponent:Exponent {
        return self.decomposed.exponent
    }
    public var significand:Self {
        return self.decomposed.significand
    }
    public var magnitude: Self {
        return sign == .minus ? -self : +self
    }
    public var nextUp:Self {
        return self + ulp
    }
    public var isNormal: Bool       { return !self.isZero || !self.isInfinite || !self.isNaN }
    public var isFinite: Bool       { return den != 0 }
    public var isZero: Bool         { return num == 0 && den != 0 }
    public var isSubnormal:Bool     { return false }
    public var isInfinite:Bool      { return den == 0 && num != 0 }
    public var isNaN:Bool           { return (num, den) == (0, 0) }
    public var isSignalingNaN:Bool  { return self.isNaN }
    public var isCanonical:Bool     { return true }
    //
    public func isIdentical(to other: Self) -> Bool {
        return self.num == other.num && self.den == other.den
    }
    public func isEqual(to other: Self) -> Bool {
        return self.isNaN || other.isNaN ? false
            :  self.isZero ? other.isZero
            :  self.isIdentical(to: other)
    }
    private func isLessThan(_ other:Self, onEqual:Bool)->Bool {
        if self.isEqual(to: other) { return onEqual }
        if self.isNaN || other.isNaN { return false }
        if self.isInfinite {
            return self.sign == .minus
        }
        if other.isInfinite {
            return other.sign == .plus
        }
        let l = self.num * other.den
        let r = other.num * self.den
        return self.den.signum() * other.den.signum() < 0 ? r < l : l < r
    }
    public func isLess(than other: Self) -> Bool {
        return self.isLessThan(other, onEqual:false)
    }
    public func isLessThanOrEqualTo(_ other: Self) -> Bool {
        return self.isLessThan(other, onEqual:true)
    }
    public func isTotallyOrdered(belowOrEqualTo other: Self) -> Bool {
        return self.isNaN ? other.isNaN
            : self.isZero && other.isZero ? self.sign == .minus || other.sign == .plus
            : self.isLessThanOrEqualTo(other)
    }
    //
    public mutating func addingProduct(_ lhs: Self, _ rhs: Self)->Self {
        return self + lhs*rhs
    }
    public mutating func addProduct(_ lhs: Self, _ rhs: Self) {
        self = self.addingProduct(lhs, rhs)
    }
    public func squareRoot(precision px:Int=Int64.bitWidth)->Self {
        if self.isNaN || self.isLess(than:0) { return Self.nan }
        if self.isZero { return self }
        let w = 2 * max(num.bitWidth, den.bitWidth, Swift.abs(px))
        return Self((num << w).squareRoot(), (den << w).squareRoot())
    }
    public mutating func formSquareRoot(precision px:Int = Int64.bitWidth) {
        self = self.squareRoot(precision:px)
    }
    public mutating func formSquareRoot() {
        self = self.squareRoot(precision:Int64.bitWidth)
    }
    //
    public func distance(to other: Self) -> Self {
        return other - self
    }
    public func advanced(by n: Self) -> Self {
        return self + n
    }
    public func signum()->Self {
        return  self.sign == .minus ? -Self(1) : +Self(1)
    }
    public mutating func round(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) {
        if self.isZero || self.isInfinite || self.isNaN { return }
        var (i, r) = self.asMixed
        let a = Swift.abs(r)
        let s = self.sign == .minus ? IntType(-1) : IntType(+1)
        switch rule {
        case .toNearestOrAwayFromZero:  i += 0.5 <= a ? s : 0
        case .toNearestOrEven:          i += 0.5 < a || 0.5 == a && i & 1 == 1 ? s : 0
        case .awayFromZero:             i += 0.0 < a ?  s : 0
        case .down:                     i += r < 0.0 ? -1 : 0
        case .up:                       i += 0.0 < r ? +1 : 0
        case .towardZero:               i += 0
        }
        self = Self(i)
    }
    public init(_ n:Element, _ d:Element) {
        var (num, den) = d < 0 ? (-n, -d) : (n, d)
        if num == 0 {
            if den != 0 { den /= den }
        } else if den == 0 {
            num = num < 0 ? -1 : +1
        } else {
            let gcd = num.greatestCommonDivisor(with: den)
            if gcd != 1 {
                num /= gcd
                den /= gcd
            }
        }
        self.init(num:num, den:den)
    }
    public init?<T>(exactly source: T) where T : BinaryInteger {
        self.init(num: Element(exactly:source)!, den:1)
    }
    public init(sign:FloatingPointSign, exponent:Element, significand:Self) {
        var q = Self(1)
        if exponent < 0 {
            q.den <<= exponent
        } else {
            q.num <<= exponent
        }
        self = (sign == .minus ? -1 : +1) * q * Swift.abs(significand)
    }
    public init(signOf: Self, magnitudeOf: Self) {
        self.init(sign:signOf.sign, exponent:Exponent(0), significand:magnitudeOf)
    }
    public init<BI:BinaryInteger>(_ value: BI)  {
        self.init(Element(value))
    }
    public init(_ n:Element) {
        self.init(num:n, den:1)
    }
    public init(_ r:Double) {
        if r.isNaN || r.isSignalingNaN {
            self.init(num:0, den:0)
        }
        else if r.isZero {
            self.init(num:0, den:(r.sign == .minus ? -1 : +1))
        }
        else if r.isInfinite {
            self.init((r.sign == .minus ? -1 : +1), 0)
        }
        else {
            let n = (r.sign == .minus ? -1 : +1) * Int(r.significand * Double(1 << Double.significandBitCount))
            let d = 1 << Double.significandBitCount
            if (r.exponent < 0) {
                self.init(Element(n), Element(d) << -r.exponent)
            } else {
                self.init(Element(n) << r.exponent,  Element(d))
            }
        }
    }
    /// - returns: `self` converted to `Double`
    public var asDouble: Double {
        if self.isNaN {
            return Double.nan
        }
        if self.isZero {
            return self.sign == .minus ? -0.0 : +0.0
        }
        if self.isInfinite {
            return self.sign == .minus ? -Double.infinity : +Double.infinity
        }
        let r = Double(BigInt(num)) / Double(BigInt(den))
        if r.isZero {       // we know it is not zero so try again with subnormal handling
            let w = Swift.min(den.trailingZeroBitCount, den.bitWidth - 1024)
            return Double(BigInt(num)) / Double(BigInt(den >> w)) / Double(BigInt(1) << w)
        }
        if r.isInfinite {   // we know it is not infinite so try with integral part
            return Double(BigInt(self.asMixed.0))
        }
        return r
    }
    public init(_ q:Self) {
        self.init(q.num, q.den)
    }
    public var description:String {
        return "(\(num)/\(den))"
    }
    public static prefix func +(_ q:Self)->Self {
        return Self(num:+q.num, den:+q.den)
    }
    public static prefix func -(_ q:Self)->Self {
        return q.isZero ? Self(num:+q.num, den:-q.den) : Self(num:-q.num, den:+q.den)
    }
    public static func *(_ lhs:Self, _ rhs:Self)->Self {
        if rhs.isNaN      { return Self.nan }
        if rhs.isZero {
            return lhs.isInfinite ? Self.nan
                : lhs.sign == rhs.sign ? Self.zero : Self.negativeZero
        }
        return Self(lhs.num * rhs.num, lhs.den * rhs.den)
    }
    public static func *(_ lhs:Self, _ rhs:Element)->Self {
        return lhs * Self(rhs)
    }
    public static func *(_ lhs:Element, _ rhs:Self)->Self {
        return Self(lhs) * rhs
    }
    public static func *= (lhs: inout Self, rhs: Self) {
        lhs = lhs * rhs
    }
    public func over(_ q:Self)->Self {
        if q.isNaN      { return Self.nan }
        if q.isInfinite {
            return self.isInfinite ? Self.nan
                : self.sign == q.sign ? Self.zero : Self.negativeZero
        }
        return Self(self.num * q.den, self.den * q.num)
    }
    public func over(_ d:Element)->Self {
        return self.over(Self(d))
    }
    public var asMixed:(IntType, Self) {
        let (q, r) = self.num.quotientAndRemainder(dividingBy: self.den)
        return (q, Self(r, self.den)) as! (Self.IntType, Self)
    }
    public func quotientAndRemainder(dividingBy other: Self)->(quotient:Self, remainder:Self) {
        let (q, r) = self.over(other).asMixed
        return (Self(q), r * other)
    }
    public func truncatingRemainder(dividingBy other: Self)->Self {
        return self.quotientAndRemainder(dividingBy: other).0
    }
    public mutating func formTruncatingRemainder(dividingBy other: Self) {
        self = self.quotientAndRemainder(dividingBy: other).0
    }
    public func remainder(dividingBy other: Self)->Self {
        return self.quotientAndRemainder(dividingBy: other).1
    }
    public mutating func formRemainder(dividingBy other: Self) {
        self = self.quotientAndRemainder(dividingBy: other).1
    }
    
    public static func /(_ lhs:Self, _ rhs:Self)->Self {
        return lhs.over(rhs)
    }
    public static func /(_ lhs:Self, _ rhs:Element)->Self {
        return lhs.over(rhs)
    }
    public static func /(_ lhs:Element, _ rhs:Self)->Self {
        return Self(lhs).over(rhs)
    }
    public static func /= (lhs: inout Self, rhs: Self) {
        lhs = lhs / rhs
    }
    public static func %(_ lhs:Self, _ rhs:Self)->Self {
        return lhs.quotientAndRemainder(dividingBy: rhs).1
    }
    public static func %(_ lhs:Self, _ rhs:Element)->Self {
        return lhs % Self(rhs)
    }
    public static func %(_ lhs:Element, _ rhs:Self)->Self {
        return Self(lhs) % rhs
    }
    public static func %= (lhs: inout Self, rhs: Self) {
        lhs = lhs % rhs
    }
    //
    public static func +(_ lhs:Self, _ rhs:Self)->Self {
        if lhs.isInfinite {
            return rhs.isZero || rhs.sign == lhs.sign ? lhs : Self.nan
        }
        if rhs.isInfinite {
            return lhs.isZero || lhs.sign == rhs.sign ? rhs : Self.nan
        }
         return Self(
            lhs.num * rhs.den + rhs.num * lhs.den,
            lhs.den * rhs.den
        )
    }
    public static func +(_ lhs:Self, _ rhs:Element)->Self {
        return lhs + Self(rhs)
    }
    public static func +(_ lhs:Element, _ rhs:Self)->Self {
        return Self(lhs) + rhs
    }
    public static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }
    public static func -(_ lhs:Self, _ rhs:Self)->Self {
        return lhs + (-rhs)
    }
    public static func -(_ lhs:Self, _ rhs:Element)->Self {
        return lhs - Self(rhs)
    }
    public static func -(_ lhs:Element, _ rhs:Self)->Self {
        return Self(lhs) - rhs
    }
    public static func -= (lhs: inout Self, rhs: Self) {
        lhs = lhs - rhs
    }
    public var numerator:Element   { return num }
    public var denominator:Element { return den }
}

extension RationalType where Element:FixedWidthInteger {}

extension Double {
    public init<Q:RationalType>(_ q:Q) {
        self.init(q.asDouble)
    }
}

public struct Rational<I:RationalElement> : RationalType {
    public typealias IntegerLiteralType = Int
    public typealias FloatLiteralType =   Double
    public typealias Element = I
    public typealias IntType = I
    public var (num, den):(I, I)
    public init(num n:I, den d:I) {
        (num, den) = (n, d)
    }
    public init(integerLiteral: IntegerLiteralType) {
        self.init(Element(integerLiteral))
    }
    public init(floatLiteral: FloatLiteralType) {
        self.init(floatLiteral)
    }
    /// maximum magnitude of the argument to exponential functions.
    /// if smaller than `-maxExponent` 0 is returned
    /// anything larger than `+maxExponent` +infinity is returned
    public static var maxExponent:Int {
        return Int(Int16.max)
    }
}

public struct BigRational : BigRationalType & Codable {
    public typealias IntegerLiteralType = Int
    public typealias FloatLiteralType = Double
    public typealias Element = BigInt
    public typealias IntType = BigInt
    public static var precision    = 64
    public static var roundingRule = FloatingPointRoundingRule.toNearestOrAwayFromZero
    public static var ATAN1 = (precision:0, value:nan)
    public static var E     = (precision:0, value:nan)
    public static var SQRT2 = (precision:0, value:nan)
    public static var LN2   = (precision:0, value:nan)
    public static var LN10  = (precision:0, value:nan)
    
    public static func getEpsilon(precision px:Int)->BigRational {
        return 1 / BigRational(IntType(1) << px.magnitude)
    }
    public var (num, den):(Element, Element)
    public init(num n:Element, den d:Element) {
        (num, den) = (n, d)
    }
    public init<I:FixedWidthInteger>(_ n:I, _ d:I) {
        self.init(Element(n), Element(d))
    }
    public init(integerLiteral: IntegerLiteralType) {
        self.init(Element(integerLiteral))
    }
    public init(floatLiteral: FloatLiteralType) {
        self.init(floatLiteral)
    }
    public var asBigRat:BigRational { return self }
    /// maximum magnitude of the argument to exponential functions.
    /// if smaller than `-maxExponent` 0 is returned
    /// anything larger than `+maxExponent` +infinity is returned
    public static var maxExponent:Int {
        return Int(Int16.max)
    }
    public func remainder(dividingBy other:BigRational,
                          precision:Int = BigRational.precision,
                          round:FloatingPointRoundingRule = BigRational.roundingRule)->BigRational
    {
        return self.quotientAndRemainder(dividingBy: other).remainder
    }
}
public typealias BigRat = BigRational

extension BigRational {
    public var asIntRat:IntRat {
        let q = self.truncated(width: Int.bitWidth - 1)
        return IntRat(num:Int(q.num), den:Int(q.den))
    }
    public func toString(radix:Int=10)->String {
        return "(\(String(num, radix:radix))/\(String(den, radix:radix)))"
    }
    public var debugDescription:String {
        let n = (sign == .minus ? "-" : "+") + "0x" + String(num.magnitude, radix:16)
        let d = (sign == .minus ? ""  : "+") + "0x" + String(den, radix:16)
        return "(\(n)/\(d))"
    }
    public func toFloatingPointString(radix:Int = 10)->String {
        if self.isNaN || self.isSignalingNaN || self.isInfinite {
            return self.asDouble.description
        }
        let (iself, fself) = self.asMixed
        let sint = String(iself.magnitude, radix:radix)
        let ilen = sint.count
        if fself.isZero { return sint + ".0" }
        let bitsPerDigit = Double.log2(Double(radix))
        let bitWidth = Swift.max(fself.num.bitWidth, fself.den.bitWidth, Int64.bitWidth)
        let ndigits = Int(Double(bitWidth) / bitsPerDigit) + 1
        var (i, r) = (self * BigInt(radix).power(ndigits)).asMixed
        if 1 <= r.magnitude * 2 {
            i += i.sign == .minus ? -1 : +1
        }
        var s = String(i.magnitude, radix:radix)

        if self.magnitude < 1 {
            s = [String](repeating:"0", count: ndigits - s.count + 1).joined() + s
        }
        s.insert(".", at:s.index(s.startIndex, offsetBy:ilen))
        while s.last == "0" { s.removeLast() }
        if s.last == "." { s.append("0") }
        return (self.sign == .minus ? "-" : "+") + s;
    }
}

// Because FixedWidthInteger is Coda
/// Signed integer type that can be a numerator and denominator of `FixedWidthRationalType`
public protocol FixedWidthRationalElement : RationalElement & FixedWidthInteger & Codable {}

extension Int:      FixedWidthRationalElement {}
extension Int8:     FixedWidthRationalElement {}
extension Int16:    FixedWidthRationalElement {}
extension Int32:    FixedWidthRationalElement {}
extension Int64:    FixedWidthRationalElement {}

extension FixedWidthRationalElement {
    public func over(_ den:Self)->FixedWidthRational<Self> {
        return FixedWidthRational(self, den)
    }
}

// FixedWidthRationalType is Codable
/// Rational number type whose numerator and denominator are `RationalElement`
public protocol FixedWidthRationalType : RationalType & Codable where Element: FixedWidthRationalElement {}

extension FixedWidthRationalType {
    public static var max:Self {
        return Self(+Element.max, 1)
    }
    public static var min:Self {
        return Self(-Element.max, 1)
    }
    public var asBigRat:BigRat {
        return BigRat(self.num, self.den)
    }
    public var exponent:Element {
        return Element(self.asDouble.exponent)
    }
    public func toFloatingPointString(radix:Int = 10)->String {
        return self.asBigRat.toFloatingPointString(radix:radix)
    }
}

public struct FixedWidthRational<I:FixedWidthRationalElement> : FixedWidthRationalType, Codable {
    public typealias IntegerLiteralType = Int
    public typealias FloatLiteralType   = Double
    public typealias Element = I
    public typealias IntType = I
    public var (num, den):(I, I)
    public init(num n:I, den d:I) {
        (num, den) = (n, d)
    }
    public init(integerLiteral: IntegerLiteralType) {
        self.init(Element(integerLiteral))
    }
    public init(floatLiteral: FloatLiteralType) {
        self.init(floatLiteral)
    }
    /// maximum magnitude of the argument to exponential functions.
    /// if smaller than `-maxExponent` 0 is returned
    /// anything larger than `+maxExponent` +infinity is returned
    public static var maxExponent:Int {
        return I.bitWidth - 1
    }
}

/// FixedWidthRational<Int>
public typealias IntRat = FixedWidthRational<Int>
