public protocol RationalElement : SignedInteger {
    init(_:Int)
}

extension BigInt:   RationalElement {}

extension RationalElement {
    public func greatestCommonDivisor(with n:Self)->Self {
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

public protocol RationalType : CustomStringConvertible, FloatingPoint, ExpressibleByFloatLiteral {
    associatedtype Element:RationalElement
    var num:Element { get set }
    var den:Element { get set }
    init(num:Element, den:Element)
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
    public var exponent:Element {
        return 1
    }
    public var significand:Self {
        return sign == .minus ? -self : +self
    }
    public mutating func formRemainder(dividingBy other: Self) {
        fatalError()
    }
    public mutating func formTruncatingRemainder(dividingBy other: Self) {
        fatalError()
    }
    public func squareRoot()->Self {
        if self < 0 { return Self.nan }
        var n = self.num
        var d = self.den
        let w = 2 * max(n.bitWidth, d.bitWidth, Int64.bitWidth)
        n <<= w
        d <<= w
        return Self(n.squareRoot(), d.squareRoot())
    }
    public mutating func formSquareRoot() {
        fatalError()
    }
    public var nextUp:Self {
        return Self.zero
    }
    public var isNormal: Bool       { return !self.isZero }
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
    public func isLess(than other: Self) -> Bool {
        if self.isNaN || other.isNaN { return false }
        let l = self.num * other.den
        let r = other.num * self.den
        return l < r
    }
    public func isLessThanOrEqualTo(_ other: Self) -> Bool {
        return self.isEqual(to:other) || self.isLess(than:other)
    }
    public func isTotallyOrdered(belowOrEqualTo other: Self) -> Bool {
        return self.isLessThanOrEqualTo(other)
    }
    //
    public mutating func addProduct(_ lhs: Self, _ rhs: Self) {
        fatalError()
    }
    public func distance(to other: Self) -> Self {
        return self - other
    }
    public func advanced(by n: Self) -> Self {
        return self + n
    }
    public var magnitude: Self {
        return sign == .minus ? -self : +self
    }
    public var asMixed:(Element, Self) {
        let (q, r) = self.num.quotientAndRemainder(dividingBy: self.den)
        return (q, Self(r, self.den))
    }
    public func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Self {
        return Self(self.asDouble.rounded(rule))
    }
    public mutating func round(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) {
        self = self.rounded(rule)
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
    public init(sign: FloatingPointSign, exponent: Element, significand: Self) {
        var n = Element(sign == .minus ? -1 : +1)
        var d = Element(1)
        if exponent < 0 {
            d <<= exponent
        } else {
            n <<= exponent
        }
        self.init(num:n * significand.num, den:d * significand.den)
    }
    public init(signOf: Self, magnitudeOf: Self) {
        self.init(num:(signOf.sign == .minus ? -1 : +1) * magnitudeOf.num, den:magnitudeOf.den)
    }
    public init<BI:BinaryInteger>(_ value: BI)  {
        self.init(num:Element(value), den:Element(1))
    }
    public init(_ n:Element) {
        self.init(num:n, den:1)
    }
    public init(_ r:Double) {
        if r.isNaN || r.isSignalingNaN {
            self.init(num:0, den:0)
        }
        else if r.isZero {
            self.init(0, (r.sign == .minus ? -1 : +1))
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
        var n = self.num
        var d = self.den
        let w = max(n.bitWidth, d.bitWidth) - Int64.bitWidth
        // print("n=\(n),d=\(d),w=\(w)")
        if w > 0 {
            n >>= w
            d >>= w
        }
        return Double(Int64(n)) / Double(Int64(d))
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
        lhs = lhs * rhs
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
}

extension Double {
    public init<Q:RationalType>(_ q:Q) {
        self.init(q.asDouble)
    }
}


public struct Rational<I:RationalElement> : RationalType {
    public typealias IntegerLiteralType = Int
    public typealias FloatLiteralType =   Double
    public typealias Element = I
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
}

import FloatingPointMath

extension Rational : FloatingPointMath {}

public typealias BigRat = Rational<BigInt>

extension RationalType where Element == BigInt {
    public func truncated(width:Int)->Self {
        let (nb, db) = (self.num.bitWidth, self.den.bitWidth)
        let mb = nb < db ? db : nb
        if mb <= width { return self }
        let sb = mb - width
        return Self(self.num >> sb, self.den >> sb)
    }
    public mutating func truncate(width:Int)->Self {
        self = self.truncated(width: width)
        return self
    }
    public var asIntRat:IntRat {
        let q = self.truncated(width: Int.bitWidth - 1)
        return IntRat(num:Int(q.num), den:Int(q.den))
    }
}

extension Rational : Codable where Element: Codable {
    public enum CodingKeys : String, CodingKey {
        public typealias RawValue = String
        case num, den
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.num = try values.decode(Element.self, forKey: .num)
        self.den = try values.decode(Element.self, forKey: .den)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.num, forKey: .num)
        try container.encode(self.den, forKey: .den)
    }
}

public protocol FixedWidthRationalElement : RationalElement & FixedWidthInteger {}

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

public protocol FixedWidthRationalType : RationalType where Element: FixedWidthRationalElement { }

extension FixedWidthRationalType {
    public static var max:Self {
        return Self(+Element.max, 1)
    }
    public static var min:Self {
        return Self(-Element.max, 1)
    }
    public var asBigRat:BigRat {
        return BigInt(Int(self.num)).over(BigInt(Int(self.den)))
    }
    public static func *(_ lhs:Self, _ rhs:Self)->Self {
        let q = (lhs.asBigRat * rhs.asBigRat).truncated(width:Element.bitWidth - 1)
        return Self(Element(Int(q.num)), Element(Int(q.den)))
    }
    public static func *(_ lhs:Self, _ rhs:Element)->Self {
        return lhs * Self(rhs)
    }
    public static func *(_ lhs:Element, _ rhs:Self)->Self {
        return Self(lhs) * rhs
    }
}

public struct FixedWidthRational<I:FixedWidthRationalElement> : FixedWidthRationalType {
    public typealias IntegerLiteralType = Int
    public typealias FloatLiteralType   = Double
    public typealias Element = I
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
}

public typealias IntRat = FixedWidthRational<Int>

extension FixedWidthRational : Codable where Element: Codable {
    public enum CodingKeys : String, CodingKey {
        public typealias RawValue = String
        case num, den
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.num = try values.decode(Element.self, forKey: .num)
        self.den = try values.decode(Element.self, forKey: .den)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.num, forKey: .num)
        try container.encode(self.den, forKey: .den)
    }
}
