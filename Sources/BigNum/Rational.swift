/// Signed integer type that can be a numerator and denominator of `RationalType`
public protocol RationalElement : SignedInteger {
    init(_:Int)
    /// The greatest common divisor of `self` and `other`, always non-negative.
    ///
    /// A *requirement* rather than a convenience, so generic `Rational<I>` code
    /// dispatches to the conformer's own implementation -- `BigInt`'s limb
    /// version, or whatever a foreign element brings -- instead of statically
    /// binding to the extension's schoolbook loop below.
    func greatestCommonDivisor(with other:Self)->Self
    /// ⌊√self⌋.  A requirement for the same dispatch reason.
    func squareRoot()->Self
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

/// Rational number type whose numerator and denominator are `RationalElement`
public protocol RationalType : CustomStringConvertible, FloatingPoint, ExpressibleByFloatLiteral {
    associatedtype Element:RationalElement
    associatedtype IntType:RationalElement
    var num:Element { get set }
    var den:Element { get set }
    init(num:Element, den:Element)
}

public protocol BigRationalType : RationalType & BigFloatingPoint {}

extension BigInt: RationalElement {
    public func over(_ den:BigInt)->BigRational {
        return BigRational(self, den)
    }
}

extension RationalType {
    /// truncate significand to `width` bits.  The body is identical to
    /// `BigRationalType`'s below; this one lives on `RationalType` so a generic
    /// `Rational<I>` -- which has no `BigFloatingPoint` statics to default the
    /// rounding rule from -- can truncate too.
    public mutating func truncate(width:Int, round:FloatingPointRoundingRule) {
        if self.isNaN || self.isZero || self.isInfinite { return }
        if width == 0       { return }
        let w = width < 0 ? -width : +width
        if den >> den.trailingZeroBitCount == 1 && num.bitWidth - 1 <= w { return }
        let s = max(den.bitWidth - 1, w)    // -1 for sign bit
        let d = Element(1) << s
        var n = (num << (s+2)) / den    // 2 bits for rounding hint
        n.truncate(width:width, round:round)
        self = Self(n >> 2, d)  // shift down and back up to discard lower bits
    }
    public func truncated(width:Int, round:FloatingPointRoundingRule)->Self {
        var result = self
        result.truncate(width:width, round:round)
        return result
    }
}

extension BigRationalType {
    /// truncate significand to `width` bits
    public mutating func truncate(width:Int, round:FloatingPointRoundingRule=Self.roundingRule) {
        if self.isNaN || self.isZero || self.isInfinite { return }
        if width == 0       { return }
        let w = width < 0 ? -width : +width
        // A power-of-two denominator is already exact, so there is nothing to
        // gain -- but only skip the work when the fraction really does fit in
        // `w` bits. Bailing out unconditionally left the memoized constants at
        // their full width (π/4 to 1151 bits keeps a 1153-bit denominator),
        // which then overflows toDouble().
        if den >> den.trailingZeroBitCount == 1 && num.bitWidth - 1 <= w { return }
        let s = max(den.bitWidth - 1, w)    // -1 for sign bit
        let d = Element(1) << s
        var n = (num << (s+2)) / den    // 2 bits for rounding hint
        n.truncate(width:width, round:round)
        self = Self(n >> 2, d)  // shift down and back up to discard lower bits
    }
    public func divided(by other:Self,
                        precision px:Int=precision,
                        round rule:FloatingPointRoundingRule=roundingRule)->Self
    {
        return self / other
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
    /// Whether `self` and `other` are stored the same way -- a stronger question
    /// than `==`, since one number has many spellings as a fraction.
    public func isIdentical(to other: Self) -> Bool {
        return self.num == other.num && self.den == other.den
    }
    ///
    /// Whether `self` and `other` are the same *number*.
    ///
    /// `init(_:_:)` reduces, so a value built through it is settled by the identity
    /// check below and nothing further is spent.  But `init(num:den:)` is a
    /// requirement of this protocol and stores what it is given, `num` and `den` are
    /// settable, and conversions use them -- `BigRat(someBigFloat)` writes
    /// `mantissa / 2^-scale` without reducing.  So an unreduced value is ordinary,
    /// not pathological, and representation equality cannot answer this.
    ///
    /// This was `isIdentical(to:)` outright, which called 2/4 and 1/2 unequal
    /// whenever the first arrived without being reduced.  Worse, `<`, `==` and `>`
    /// were then *all* false for one number, and `Comparable` requires exactly one
    /// to hold.
    ///
    /// Cross-multiplication settles it, and is what `isLessThan` already pays for
    /// every unequal pair.  It does not care about the sign of either denominator:
    /// `-1/-2` and `1/2` give the same products.
    ///
    public func isEqual(to other: Self) -> Bool {
        if self.isNaN || other.isNaN { return false }
        if self.isIdentical(to: other) { return true }
        if self.isZero || other.isZero { return self.isZero && other.isZero }
        if self.isInfinite || other.isInfinite {
            return self.isInfinite && other.isInfinite && self.sign == other.sign
        }
        return self.num * other.den == other.num * self.den
    }
    /// `Hashable` asks that equal values hash equally, so this hashes what
    /// `init(_:_:)` would have stored.  The synthesized conformance hashed `num` and
    /// `den` as they lay, which put one number in two buckets -- and a `Set` then
    /// holds it twice.
    ///
    /// The reduction costs a gcd, paid only when hashing and not when comparing.
    /// ±0 have to agree, being `==`; NaN equals nothing, itself included, so its
    /// hash is free to be anything.
    public func hash(into hasher: inout Hasher) {
        if self.isZero     { hasher.combine(0) ; hasher.combine(0) ; return }
        if self.isNaN      { hasher.combine(1) ; hasher.combine(0) ; return }
        if self.isInfinite { hasher.combine(2) ; hasher.combine(self.sign == .minus ? -1 : 1) ; return }
        var (n, d) = den < 0 ? (-num, -den) : (num, den)
        let g = n.greatestCommonDivisor(with: d)
        if g != 1 { n /= g ; d /= g }
        hasher.combine(n)
        hasher.combine(d)
    }
    private func isLessThan(_ other:Self, onEqual:Bool)->Bool {
        if self.isNaN || other.isNaN { return false }
        if self.isIdentical(to: other) { return onEqual }
        if self.isZero && other.isZero { return onEqual }
        if self.isInfinite {
            // two infinities of one sign are equal, which the identity check above
            // only catches when they are spelled the same way
            if other.isInfinite && self.sign == other.sign { return onEqual }
            return self.sign == .minus
        }
        if other.isInfinite {
            return other.sign == .plus
        }
        // Equality falls out of the same two products, so this does not call
        // `isEqual(to:)` and pay for them twice.
        let l = self.num * other.den
        let r = other.num * self.den
        if l == r { return onEqual }
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
    public mutating func formSquareRoot(precision px:Int=Int64.bitWidth) {
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
        var (i, r) = self.toMixed()
        let a = Swift.abs(r)
        let s = self.sign == .minus ? IntType(-1) : IntType(+1)
        switch rule {
        case .toNearestOrAwayFromZero:  i += 0.5 <= a ? s : 0
        case .toNearestOrEven:          i += 0.5 < a || 0.5 == a && i & 1 == 1 ? s : 0
        case .awayFromZero:             i += 0.0 < a ?  s : 0
        case .down:                     i += r < 0.0 ? -1 : 0
        case .up:                       i += 0.0 < r ? +1 : 0
        case .towardZero:               i += 0
                                        @unknown default:               fatalError()
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
    public func toDouble()->Double {
        if self.isNaN {
            return Double.nan
        }
        if self.isZero {
            return self.sign == .minus ? -0.0 : +0.0
        }
        if self.isInfinite {
            return self.sign == .minus ? -Double.infinity : +Double.infinity
        }
        var (n, d) = (BigInt(num), BigInt(den))
        // Both sides can sit far above Double's range while their ratio is
        // perfectly ordinary -- π/4 held to 1151 bits, say. Double(n)/Double(d)
        // would be inf/inf, i.e. NaN, so shift them down together first: the
        // quotient is unchanged and ~1000 bits of it survive, far more than the
        // 53 a Double can keep.
        let excess = Swift.max(n.bitWidth, d.bitWidth) - 1000
        if 0 < excess {
            let w = Swift.min(excess, Swift.min(n.bitWidth, d.bitWidth) - 1)
            if 0 < w { (n, d) = (n >> w, d >> w) }
        }
        let r = Double(n) / Double(d)
        if r.isZero {       // we know it is not zero so try again with subnormal handling
            let w = Swift.min(den.trailingZeroBitCount, den.bitWidth - 1024)
            return Double(BigInt(num)) / Double(BigInt(den >> w)) / Double(BigInt(1) << w)
        }
        if r.isInfinite {   // we know it is not infinite so try with integral part
            return Double(BigInt(self.toMixed().0))
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
    public func toMixed()->(IntType, Self) {
        let (q, r) = self.num.quotientAndRemainder(dividingBy: self.den)
        return (q, Self(r, self.den)) as! (Self.IntType, Self)
    }
    public func quotientAndRemainder(dividingBy other: Self)->(quotient:Self, remainder:Self) {
        let (q, r) = self.over(other).toMixed()
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
        self.init(q.toDouble())
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
}

public struct BigRational : BigRationalType & Codable {
    public typealias IntegerLiteralType = Int
    public typealias FloatLiteralType = Double
    public typealias Element = BigInt
    public typealias IntType = BigInt
    public static var precision    = 128
    public static var roundingRule = FloatingPointRoundingRule.toNearestOrAwayFromZero
    public static var pi: Self { return Self.PI(precision:Self.precision) }
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
    public func toBigRat()->BigRational { return self }
    public func toBigFloat()->BigFloat { return BigFloat(self) }
    /// maximum magnitude of the argument to exponential functions.
    /// if smaller than `-expLimit` 0 is returned
    /// anything larger than `+expLimit` +infinity is returned
    public static var expLimit = Self(Int16.max)
    public func remainder(dividingBy other:BigRational,
                          precision:Int = BigRational.precision,
                          round:FloatingPointRoundingRule = BigRational.roundingRule)->BigRational
    {
        return self.quotientAndRemainder(dividingBy: other).remainder
    }
}
public typealias BigRat = BigRational

extension BigRational : CustomDebugStringConvertible {
    public func toIntRat()->IntRat {
        let q = self.truncated(width: Int.bitWidth - 1)
        return IntRat(num:Int(q.num), den:Int(q.den))
    }
    ///
    /// `self` as text.  `BigRat` is where all three of `BigNum.Format`'s shapes
    /// are actually produced -- `BigFloat` and the fixed-width rationals convert
    /// here first, since a `BigRat` can hold any of them exactly.
    ///
    public func toString(_ format:BigNum.Format = .point, radix:Int = 10)->String {
        switch format {
        case .point:    return self.pointString(radix:radix)
        case .fraction: return self.fractionString(radix:radix)
        case .exponent: return self.exponentString()
        }
    }

    /// A `BigRat` debugs as the ratio it is, in hex -- the shape that shows what
    /// is actually stored rather than a rounded rendering of it.
    public var debugDescription:String {
        return self.toString(.fraction, radix:16)
    }

    /// `(+22/7)`, or `(+0x16/0x7)` where the radix wants announcing.  NaN, the
    /// infinities and zero print bare and keep the denominator's sign, because
    /// their numerator and denominator *are* the value: `(+0/0)` is NaN in every
    /// radix, and `(+0/-1)` is the only way to see a negative zero.
    private func fractionString(radix:Int)->String {
        let sign   = num < 0 ? "-" : "+"
        let bare   = !self.isFinite || self.isZero
        let prefix = bare ? "" : BigNum.radixPrefix(radix)
        return "(\(sign)\(prefix)\(String(num.magnitude, radix:radix))"
             + "/\(prefix)\(String(den, radix:radix)))"
    }

    /// `+0x1.6a09e667f3bcc908p0`: the `.point` form in radix 16 with the point
    /// walked to just past the leading digit, and the four bits per hex digit
    /// that cost accumulated into `p`.
    private func exponentString()->String {
        var s = self.pointString(radix:16)
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
                s.remove(at: s.index(s.endIndex, offsetBy: -3))
                p += 4
            }
        }
        s.insert(contentsOf: "0x", at: s.index(s.startIndex, offsetBy:1))
        return s + "p\(p)"
    }

    private func pointString(radix:Int)->String {
        let ssign = self.sign == .minus ? "-" : "+"
        if self.isNaN || self.isSignalingNaN { return "nan" }
        if self.isInfinite {
            return ssign + "infinity"
        }
        let (iself, fself) = self.toMixed()
        let sint = String(iself.magnitude, radix:radix)
        let ilen = sint.count
        if fself.isZero { return ssign + sint + ".0" }
        let bitsPerDigit = Double.log2(Double(radix))
        let bitWidth = Swift.max(fself.num.bitWidth, fself.den.bitWidth, Int64.bitWidth)
        let ndigits = Int(Double(bitWidth) / bitsPerDigit) + 1
        var (i, r) = (self * BigInt(radix).power(ndigits)).toMixed()
        if 1 <= r.magnitude * 2 {
            i += i < 0 ? -1 : +1     // round the last digit away from zero
        }
        var s = String(i.magnitude, radix:radix)
        if self.magnitude < 1 {
            s = [String](repeating:"0", count: ndigits - s.count + 1).joined() + s
        }
        s.insert(".", at:s.index(s.startIndex, offsetBy:ilen))
        while s.last == "0" { s.removeLast() }
        if s.last == "." { s.append("0") }
        return ssign + s;
    }
}

#if swift(>=5.5)
extension BigRational: Sendable { }
#endif

// Because FixedWidthInteger is Coda
/// Signed integer type that can be a numerator and denominator of `FixedWidthRationalType`
public protocol FixedWidthRationalElement : RationalElement & FixedWidthInteger & Codable {}

extension Int:      FixedWidthRationalElement {}
extension Int8:     FixedWidthRationalElement {}
extension Int16:    FixedWidthRationalElement {}
extension Int32:    FixedWidthRationalElement {}
extension Int64:    FixedWidthRationalElement {}
#if compiler(>=6.0)
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension Int128:   FixedWidthRationalElement {}
#endif

extension FixedWidthRationalElement {
    public func over(_ den:Self)->FixedWidthRational<Self> {
        return FixedWidthRational(self, den)
    }
}

// FixedWidthRationalType is Codable
/// Rational number type whose numerator and denominator are `RationalElement`
public protocol FixedWidthRationalType : RationalType, CustomDebugStringConvertible,Codable
  where Element: FixedWidthRationalElement {}

extension FixedWidthRationalType {
    public static var max:Self {
        return Self(+Element.max, 1)
    }
    public static var min:Self {
        return Self(-Element.max, 1)
    }
    public func toBigRat()->BigRat {
        return BigRat(self.num, self.den)
    }
    public var exponent:Element {
        return Element(self.toDouble().exponent)
    }
    public func toString(_ format:BigNum.Format = .point, radix:Int = 10)->String {
        return self.toBigRat().toString(format, radix:radix)
    }
    public var debugDescription: String {
        return self.toBigRat().debugDescription
    }
    //
    // override RationalType#{squareRoot,formSquareRoot}
    //
    public func squareRoot(precision px:Int=0)->Self {
        if self.isNaN || self.isLess(than:0) { return Self.nan }
        if self.isZero { return self }
        let nd = num * den
        if nd <= (1 << 20) {
            return Self(Double(self).squareRoot())
        } else {
            return Self((num * den).squareRoot(), den)
        }
    }
    public mutating func formSquareRoot(precision px:Int=0) {
        self = self.squareRoot(precision:0)
    }
    public mutating func formSquareRoot() {
        self = self.squareRoot(precision:0)
    }
}

public struct FixedWidthRational<I:FixedWidthRationalElement> :
  FixedWidthRationalType, Codable
{
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
}

/// FixedWidthRational<Int>
public typealias IntRat = FixedWidthRational<Int>
