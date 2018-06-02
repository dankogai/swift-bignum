/// Signed integer type that can be a numerator and denominator of `RationalType`
public protocol RationalElement : SignedInteger {
    init(_:Int)
}

extension BigInt:   RationalElement {}

extension RationalElement {
    /// - returns: the greatest common divisor of `self`
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

import FloatingPointMath

/// Rational number type whose numerator and denominator are `RationalElement`
public protocol RationalType : CustomStringConvertible, FloatingPoint, ExpressibleByFloatLiteral, FloatingPointMath {
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
        return Element(num.bitWidth - den.bitWidth)
    }
    public var significand:Self {
        let e = self.exponent
        return e < 0 ? Self(num << -e, den) : Self(num, den << e)
    }
    public var magnitude: Self {
        return sign == .minus ? -self : +self
    }
    public func squareRoot(precision px:Int = Int64.bitWidth)->Self {
        if self.isNaN || self.isLess(than:0) { return Self.nan }
        if self.isZero { return Self.zero }
        var n = self.num
        var d = self.den
        let w = 2 * max(n.bitWidth, d.bitWidth, px)
        n <<= w
        d <<= w
        return Self(n.squareRoot(), d.squareRoot())
    }
    public mutating func formSquareRoot(precision px:Int = Int64.bitWidth) {
        self = self.squareRoot(precision:px)
    }
    public mutating func formSquareRoot() {
        self = self.squareRoot(precision:Int64.bitWidth)
    }
    public var nextUp:Self {
        return self + ulp
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
    public mutating func addingProduct(_ lhs: Self, _ rhs: Self)->Self {
        return self + lhs*rhs
    }
    public mutating func addProduct(_ lhs: Self, _ rhs: Self) {
        self = self.addingProduct(lhs, rhs)
    }
    public func distance(to other: Self) -> Self {
        return self - other
    }
    public func advanced(by n: Self) -> Self {
        return self + n
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
    public var asMixed:(Element, Self) {
        let (q, r) = self.num.quotientAndRemainder(dividingBy: self.den)
        return (q, Self(r, self.den))
    }
    public func quotientAndRemainder(dividingBy other: Self)->(Self, Self) {
        let (q, r) = self.over(other).asMixed
        return (Self(q), r * other)
    }
     public mutating func formRemainder(dividingBy other: Self) {
        self = self.quotientAndRemainder(dividingBy: other).1
    }
    public mutating func formTruncatingRemainder(dividingBy other: Self) {
        self = self.quotientAndRemainder(dividingBy: other).0
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

extension RationalType {
    public init(_ bq:BigRat) {
        self.init(Element(bq.num), Element(bq.den))
    }
    public var asBigRat:BigRat {
        if Self.self == BigRat.self { return self as! BigRat }
        return BigInt(Element(self.num)).over(BigInt(Element(self.den)))
    }
    public func truncated(width:Int = Int64.bitWidth)->Self {
        if width == 0 { return self }
        let mb = max(self.num.bitWidth, self.den.bitWidth)
        let w = width < 0 ? -width : +width
        if mb <= w { return self }
        let sb = mb - w
        return Self(self.num >> sb, self.den >> sb)
    }
    public mutating func truncate(width:Int) {
        self = self.truncated(width: width)
    }
    public static func sqrt(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        return x.squareRoot(precision: px)
    }
    public static func exp(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        if x.isNaN      { return nan }
        if x.isInfinite { return x.sign == .minus ? -infinity : +infinity }
        if x.isZero     { return 1 }
        if x.isLess(than:0)             { return 1/exp(-x, precision:px) }
        if x.magnitude.isLess(than:1)   { return exp(1/x, precision:px) }
        let epsilon = BigInt(1).over(1 << px.magnitude)
        var (r, n, d) = (BigRat(1), BigRat(1), BigInt(1))
        for i in 1 ... Int(px.magnitude) {
            n *= x.asBigRat
            d *= BigInt(i)
            let t = n / d
            r += t
            if t < epsilon { break }
        }
        // debugPrint("r=\(r)")
        return px < 0 ? Self(r) : Self(r).truncated(width:px)
    }
    /// binary log
    public static func log2(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        if x.isLess(than:1) { return -log2(1/x, precision:px) }
        if x.isEqual(to:1)  { return zero }
        var (ilog, t) = (x.exponent, x.significand)
        if t < 1 { t *= Self(Self.radix); ilog -= 1 }
        var  u = Element(0)
        for _ in 0 ..< px.magnitude {
            u <<= 1
            t *= t
            if 2 <= t {
                u += 1
                t /= 2
            }
            t.truncate(width:px)
        }
        let r = Self(ilog) + Self(u).over(1 << Swift.abs(px))
        return px < 0 ? r : r.truncated(width:px)
    }
    /// natural log
    public static func log(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        let r = log2(x, precision:px) / LN2(precision:px * 2)
        return px < 0 ? r : r.truncated(width:px)
    }
    /// log of base 10
    public static func log10(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        return log2(x, precision:px) / LB10(precision:px * 2)
    }
}

extension RationalType where Element:FixedWidthInteger {}

extension Double {
    public init<Q:RationalType>(_ q:Q) {
        self.init(q.asDouble)
    }
}

extension BigNum {
    public static var constants = [String:(value:Any,precision:Int)]()
}
extension RationalType {
    public static var typeName:String {
        return String(describing: type(of:Self.zero))
    }
    public static func getSetConstant(_ name:String, precision:Int, getter:(Int)->Self) -> Self {
        let k = "\(Self.typeName).\(name)"
        let px = Swift.abs(precision)
        // debugPrint("\(k):\(px)")
        if let v = BigNum.constants[k] {
            if px <= v.precision { return (v.value as! Self).truncated(width: px)}
        }
        let v = getter(px)
        BigNum.constants[k] = (value:v, precision:px)
        return v
    }
    public static func E(precision px:Int = Int64.bitWidth)->Self {
        return getSetConstant("E", precision:px) {
            Self.exp(1, precision:$0)
        }
    }
    public static func LN2(precision px:Int = Int64.bitWidth)->Self {
        return getSetConstant("LN2", precision:px) {
            Self.log2(Self.E(precision:$0), precision:$0)
        }
    }
    public static func LB10(precision px:Int = Int64.bitWidth)->Self {
        return getSetConstant("LB10", precision:px) {
            Self.log2(10, precision:$0)
        }
    }
    /// π/4 in precision `px`.  Bellard's Formula
    public static func ATAN1(precision px:Int = Int64.bitWidth, verbose:Bool=false)->Self {
        return getSetConstant("ATAN1", precision: px) {
            let epsilon = BigInt(1).over(1 << px.magnitude)
            var p64 = Self(0)
            for i in 0..<Int($0.magnitude) {
                var t = Self(0)
                t -= Self(1<<5) / Self( 4 * i + 1)
                t -= Self(1<<0) / Self( 4 * i + 3)
                t += Self(1<<8) / Self(10 * i + 1)
                t -= Self(1<<6) / Self(10 * i + 3)
                t -= Self(1<<2) / Self(10 * i + 5)
                t -= Self(1<<2) / Self(10 * i + 7)
                t += Self(1<<0) / Self(10 * i + 9)
                if 0 < i {
                    t /= Self(BigInt(1) << (10 * i))
                }
                p64 += i & 1 == 1 ? -t : t
                // p64.truncate(px)
                if verbose {
                    print("ATAN1(precision:\(px)):i=\(i),t=\(t.asDouble)")
                }
                // t.truncate(px)
                if t < Self(epsilon) { break }
            }
            p64 /= Self(1<<8)
            return p64.truncated(width: $0)
        }
    }
    /// π in precision `px`.  4*atan(1)
    public static func PI(precision px:Int = Int64.bitWidth)->Self {
        return 4*ATAN1(precision:px)
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

public typealias BigRat = Rational<BigInt>

extension RationalType where Element == BigInt {
    public var asIntRat:IntRat {
        let q = self.truncated(width: Int.bitWidth - 1)
        return IntRat(num:Int(q.num), den:Int(q.den))
    }
    public func toFloatingPointString(radix:Int = 10)->String {
        let (iself, fself) = self.asMixed
        let sint = String(iself, radix:radix)
        let ilen = sint.count
        if fself.isZero { return sint + ".0" }
        let bitsPerDigit = Double.log2(Double(radix))
        let bitWidth = Swift.max(fself.num.bitWidth, fself.den.bitWidth, Int64.bitWidth)
        let ndigits = Int(Double(bitWidth) / bitsPerDigit) + 1
        var (i, r) = (self * Self(BigInt(radix).power(ndigits))).asMixed
        if 1 <= r.magnitude * 2 {
            i += i.sign == .minus ? -1 : +1
        }
        var s = String(i, radix:radix)
        if self.magnitude < 1 {
            s = "0." + s
        } else {
            s.insert(".", at:s.index(s.startIndex, offsetBy:ilen))
        }
        while s.last == "0" { s.removeLast() }
        if s.last == "." { s.append("0") }
        return s;
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
        return BigInt(Int(self.num)).over(BigInt(Int(self.den)))
    }
    public var exponent:Element {
        return Element(self.asDouble.exponent)
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
    public func toFloatingPointString(radix:Int = 10)->String {
        return self.asBigRat.toFloatingPointString(radix:radix)
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

/// FixedWidthRational<Int>
public typealias IntRat = FixedWidthRational<Int>
