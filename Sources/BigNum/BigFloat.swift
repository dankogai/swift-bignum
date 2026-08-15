/// conforming to BigFloatingPoint
///
/// Generic over its significand: `BigFloatOf<I>` stores its mantissa in any
/// `BigIntegerType & RationalElement`, and `BigFloat` — the workhorse — is
/// `BigFloatOf<BigInt>`.  The arithmetic below only ever speaks `IntType`, so a
/// foreign big integer (one backed by GMP, or by JavaScriptCore) rides the same
/// machinery by conforming its element type to those two protocols.
public struct BigFloatOf<IntType: BigIntegerType & RationalElement>: Equatable, Hashable, Codable {  // automatic conformance to Equatable but needs to be overridden
    public typealias IntegerLiteralType = Int
    public typealias FloatLiteralType   = Double
    public typealias Exponent           = Int
    public typealias Significand        = IntType
    public typealias Magnitude          = BigFloatOf
    public typealias RawExponent        = UInt
    public typealias RawSignificand     = IntType.Magnitude
    public typealias Stride             = BigFloatOf
    public var scale:Exponent           // stored property
    public var mantissa:Significand     // stored property
    // basic init.  `trailingZeroBitCount` of zero is convention: BigInt says 0,
    // the stdlib documents "equal to bitWidth" -- so a zero mantissa must not
    // consult it, or the scale smears and ±0's encoding breaks.
    public init(scale: Exponent, mantissa:Significand) {
        let shift = mantissa == 0 ? 0 : mantissa.trailingZeroBitCount
        self.scale    =    scale  + shift
        self.mantissa = mantissa >> shift
    }
    public init(_ other:Self) {
        self.scale    = other.scale
        self.mantissa = other.mantissa
    }
}

/// The specialization the pre-generic `BigFloat` was, and the name almost every
/// caller still wants.
public typealias BigFloat = BigFloatOf<BigInt>

// Generic types cannot hold static *stored* properties, so the three knobs the
// concrete `BigFloat` used to keep live in module-level storage instead, one
// slot per specialization.  The observable API is unchanged:
// `BigFloat.precision = 256` still compiles and still means what it meant.
private var _precisionStore    = [ObjectIdentifier: Int]()
private var _roundingRuleStore = [ObjectIdentifier: FloatingPointRoundingRule]()
private var _expLimitStore     = [ObjectIdentifier: Any]()

extension BigFloatOf {
    public static var precision: Int {
        get { return _precisionStore[ObjectIdentifier(Self.self)] ?? 128 }
        set { _precisionStore[ObjectIdentifier(Self.self)] = newValue }
    }
    public static var roundingRule: FloatingPointRoundingRule {
        get { return _roundingRuleStore[ObjectIdentifier(Self.self)] ?? .toNearestOrAwayFromZero }
        set { _roundingRuleStore[ObjectIdentifier(Self.self)] = newValue }
    }
    public static var expLimit: Self {
        get { return _expLimitStore[ObjectIdentifier(Self.self)] as? Self ?? Self(Int16.max) }
        set { _expLimitStore[ObjectIdentifier(Self.self)] = newValue }
    }
}
// override == to introduce NaN
extension BigFloatOf {
    public static var nan:BigFloatOf {
        return BigFloatOf(scale:Int.max, mantissa:+1)
    }
    public var isNaN:Bool {
        return scale != -Int.max-1 && Swift.abs(scale) == Int.max && mantissa == +1
    }
    public static var signalingNaN:BigFloatOf {
        return BigFloatOf(scale:Int.max, mantissa:-1)
    }
    public var isSignalingNaN:Bool {
        return scale != -Int.max-1 && Swift.abs(scale) == Int.max && mantissa == -1
    }
    public static var infinity:BigFloatOf {
        return BigFloatOf(scale:Int.max, mantissa:0)
    }
    public var isInfinite:Bool {
        return scale != -Int.max-1 && Swift.abs(self.scale) == Int.max && mantissa == 0
    }
    public var isFinite: Bool    { return !isNaN && !isInfinite }
    public static var zero:BigFloatOf         { return BigFloatOf(scale:0, mantissa:0) }
    public static var negativeZero:BigFloatOf { return BigFloatOf(scale:-Int.max-1, mantissa:0) }
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
    public static prefix func -(_ bf:BigFloatOf)->BigFloatOf {
        var result = bf
        result.negate()
        return result
    }
    public static prefix func +(_ bf:BigFloatOf)->BigFloatOf {
        return bf
    }
    public var exponent:Exponent {
        if self.isNaN || self.isSignalingNaN || self.isZero || self.isInfinite { return scale }
        return scale + (mantissa.bitWidth-2)
    }
    public var significand:BigFloatOf {
        // print("\(#line)", self)
        if self.isNaN || self.isSignalingNaN || self.isZero || self.isInfinite { return self }
        return BigFloatOf(scale:-(mantissa.bitWidth-2), mantissa:self.mantissa)
    }
    public var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:BigFloatOf) {
        return (sign:sign, exponent:exponent, significand:significand)
    }
    public init(sign:FloatingPointSign, exponent:Exponent, significand:BigFloatOf) {
        scale    = exponent + significand.scale - (significand.mantissa.bitWidth-1)
        mantissa = sign == .minus ? -significand.mantissa : +significand.mantissa
        let shift = mantissa == 0 ? 0 : mantissa.trailingZeroBitCount
        scale     += shift
        mantissa >>= shift
    }
}
/// BigFloatOf -> BinaryFloatingPoint
extension BinaryFloatingPoint {
    public init<I>(_ bf:BigFloatOf<I>) {
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
/// BigFloatOf -> Double
extension Double {
    public init<I>(_ bf:BigFloatOf<I>) { // tailored becaused it is the most frequently used
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
/// BigFloatOf -> BigRat, exactly.  `BigInt(bf.mantissa)` is exact for any
/// `BinaryInteger`, so this holds for every specialization, not just `BigFloat`.
extension BigRat {
    public init<I>(_ bf:BigFloatOf<I>) {
        if bf.isNaN                 { self = BigRat.nan }
        else if bf.isSignalingNaN   { self = BigRat.signalingNaN }
        else if bf.isInfinite       { self = bf.sign == .minus ? -BigRat.infinity : +.infinity }
        else if bf.isZero           { self = bf.sign == .minus ? -BigRat.zero : +BigRat.zero }
        else {
            (num, den) = (BigInt(bf.mantissa), 1)
            if bf.scale < 0 {
                den <<= -bf.scale
            } else {
                num <<= +bf.scale
            }
        }
    }
}
/// BigFloatOf -> Rational over the same element, exactly.  This is the one the
/// arithmetic below uses, so a `BigFloatOf<I>` division never has to leave `I`.
extension Rational where I: BigIntegerType {
    public init(_ bf:BigFloatOf<I>) {
        if bf.isNaN                 { self = Rational.nan }
        else if bf.isSignalingNaN   { self = Rational.signalingNaN }
        else if bf.isInfinite       { self = bf.sign == .minus ? -Rational.infinity : +.infinity }
        else if bf.isZero           { self = bf.sign == .minus ? -Rational.zero : +Rational.zero }
        else {
            self.init(num:bf.mantissa, den:1)
            if bf.scale < 0 {
                den <<= -bf.scale
            } else {
                num <<= +bf.scale
            }
        }
    }
}
/// init from others
extension BigFloatOf : ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    public init?<T:BinaryInteger>(exactly bi:T) {
        mantissa = Significand(bi)
        scale = 0
        let shift = mantissa == 0 ? 0 : mantissa.trailingZeroBitCount
        scale     += shift
        mantissa >>= shift
    }
    /// BinaryInteger -> BigFloatOf
    public init<T:BinaryInteger>(_ bi:T) { self.init(exactly:bi)! }
    public init(integerLiteral value: Int) { self.init(value) }
    /// BinaryFloatingPoint -> BigFloatOf
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
    public func toDouble()->Double { return Double(self) }
    public init(floatLiteral value: Double) { self.init(value) }
    // implement truncate() here so init(_q:RationalType) can use it
    public mutating func truncate(width:Int, round:FloatingPointRoundingRule=Self.roundingRule) {
        mantissa.truncate(width: width, round: round)
    }
    public func truncated(width:Int, round:FloatingPointRoundingRule=Self.roundingRule)->BigFloatOf {
        var result = self
        result.truncate(width:width, round:round)
        return result
    }
    // we have truncate, we have round
    public mutating func round(_ rule:FloatingPointRoundingRule=Self.roundingRule) {
        // ±0, ±∞ and NaN are already whole -- and their `scale` is Int.min or
        // Int.max, which would overflow the arithmetic below
        if self.isZero || self.isInfinite || self.isNaN { return }
        if 0 <= scale { return }    // mantissa << scale is an integer already
        let shift = -scale
        let minus = mantissa < 0
        let a = Swift.abs(mantissa)
        let i = a >> shift              // ⌊|self|⌋
        let r = a - (i << shift)        // 0 <= r < 1, as a multiple of 2^scale
        let half = Significand(1) << (shift - 1)
        let up:Bool
        switch rule {
        case .toNearestOrAwayFromZero:  up = half <= r
        case .toNearestOrEven:          up = half < r || half == r && i & 1 == 1
        case .awayFromZero:             up = 0 < r
        case .towardZero:               up = false
        case .down:                     up = 0 < r &&  minus   // toward -∞
        case .up:                       up = 0 < r && !minus   // toward +∞
        @unknown default:               fatalError()
        }
        let n = up ? i + 1 : i
        // keep the sign when we round to zero, the way -0.2 -> -0.0 does
        self = n == 0 ? (minus ? Self.negativeZero : Self.zero)
                      : Self(scale:0, mantissa: minus ? -n : n)
    }
    public func rounded(_ rule:FloatingPointRoundingRule=Self.roundingRule)->BigFloatOf {
        var result = self
        result.round(rule)
        return result
    }
    /// RationalType -> BigFloatOf
    public init<T:RationalType>(_ q:T,
                                precision px:Int = Self.precision,
                                round rule:FloatingPointRoundingRule=Self.roundingRule)
    {
        if      q.isNaN     { self = .nan }
        else if q.isZero    { self = q.sign == .minus ? .negativeZero : .zero }
        else if q.isInfinite{ self = q.sign == .minus ? -.infinity : +.infinity }
        else {
            let w = max(q.num.bitWidth, q.den.bitWidth) - 1
            let qt = IntType(q.num).over(IntType(q.den)).truncated(width:w+px, round:rule)
            self = BigFloatOf(scale:-qt.den.trailingZeroBitCount, mantissa:qt.num)
        }
    }
}
extension BigFloatOf {
    public func toBigRat()->BigRat {
        return BigRat(self)
    }
    /// `self` as the exact ratio it is, over the same element type.
    public func toRational()->Rational<IntType> {
        return Rational<IntType>(self)
    }
}
// override == to introduce NaN
extension BigFloatOf {
    public func isIdentical(to other:BigFloatOf)->Bool {
        return self.scale == other.scale && self.mantissa == other.mantissa
    }
    public static func ===(_ lhs:BigFloatOf, _ rhs:BigFloatOf)->Bool {
        return lhs.isIdentical(to:rhs)
    }
    ///
    /// Whether `self` and `other` are the same *number*.
    ///
    /// `init(scale:mantissa:)` normalizes -- it moves the mantissa's trailing zeros
    /// into the scale -- so a value built through it is settled by the identity
    /// check below.  Two things break that invariant, and neither requires doing
    /// anything unusual:
    ///
    ///  *  `truncate(width:)` rounds the mantissa in place, zeroing its low bits
    ///     without moving them into the scale.  `BigFloat.SQRT2(precision: 128)`
    ///     comes back as a 641-bit mantissa with 512 trailing zeros, where
    ///     `BigFloat.sqrt(BigFloat(2))` -- the same number -- has 129 bits.
    ///  *  `scale` and `mantissa` are settable `public var`s, so any caller can
    ///     denormalize a value. That alone rules out representation equality.
    ///
    /// This was `isIdentical(to:)` outright, which called those two values unequal.
    /// The consequence was worse than a wrong answer: `<`, `==` and `>` were *all*
    /// false for them, and `Comparable` requires exactly one to hold.  `isLess
    /// (than:)` compares by subtraction and was right the whole time, so `==` was
    /// the only liar.
    ///
    public func isEqual(to other:BigFloatOf)->Bool {
        if self.isNaN || other.isNaN { return false }
        if self.isIdentical(to: other) { return true }
        // ±0 equal each other and nothing else.  ±∞ equal only themselves, which
        // the identity check has already settled, there being one spelling of each.
        if self.isZero || other.isZero { return self.isZero && other.isZero }
        if self.isInfinite || other.isInfinite { return false }
        // Finite and non-zero on both sides: compare what `init(scale:mantissa:)`
        // would have stored, without building it.
        let ls = self.mantissa.trailingZeroBitCount
        let rs = other.mantissa.trailingZeroBitCount
        return self.scale + ls == other.scale + rs
          &&   self.mantissa >> ls == other.mantissa >> rs
    }
    public static func ==(_ lhs:BigFloatOf, _ rhs:BigFloatOf)->Bool {
        return lhs.isEqual(to:rhs)
    }
    /// `Hashable` asks that equal values hash equally, so this hashes the
    /// normalized form for the same reason `isEqual(to:)` compares it.  The
    /// synthesized conformance hashed the stored properties, which put the same
    /// number in two buckets.
    ///
    /// ±0 have to agree, being `==`.  NaN needs no care -- it equals nothing,
    /// itself included -- but keeping the two spellings apart costs nothing.
    public func hash(into hasher: inout Hasher) {
        if self.isNaN  { hasher.combine(Int.max) ; hasher.combine(mantissa) ; return }
        if self.isZero { hasher.combine(0) ; hasher.combine(Significand.zero) ; return }
        let shift = mantissa.trailingZeroBitCount
        hasher.combine(scale + shift)
        hasher.combine(mantissa >> shift)
    }
}
/// comparison.  Now we need infinity and isInfinite
extension BigFloatOf : Comparable {
    public static func +(_ lhs:BigFloatOf, _ rhs:BigFloatOf)->BigFloatOf {
        if lhs.isNaN || rhs.isNaN { return BigFloatOf.nan }
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
        return BigFloatOf(scale:es - Swift.abs(ds), mantissa:m)
    }
    public static func -(_ lhs:BigFloatOf, _ rhs:BigFloatOf)->BigFloatOf {
        return lhs + (-rhs)
    }
    func isLessThan(_ other:BigFloatOf, onEqual:Bool)->Bool {
        return self.isEqual(to:other) ? onEqual :  (self - other).sign == .minus
    }
    public func isLess(than other:BigFloatOf)->Bool {
        return self.isLessThan(other, onEqual:false)
    }
    public static func <(_ lhs:BigFloatOf, _ rhs:BigFloatOf)->Bool {
        return lhs.isLess(than:rhs)
    }
    public func isLessThanOrEqualTo(_ other:BigFloatOf)->Bool {
        return self.isLessThan(other, onEqual:true)
    }
    public static func <=(_ lhs:BigFloatOf, _ rhs:BigFloatOf)->Bool {
        return lhs.isLessThanOrEqualTo(rhs)
    }
    public func isTotallyOrdered(belowOrEqualTo other: BigFloatOf) -> Bool {
        return self.isNaN ? other.isNaN
          : self.isZero && other.isZero ? self.sign == .minus || other.sign == .plus
          : self.isLessThanOrEqualTo(other)
    }
}
/// SignedNumeric!
extension BigFloatOf : SignedNumeric {
    public var magnitude: BigFloatOf {
        return self.sign == .minus ? -self : +self
    }
    public static func -= (lhs: inout BigFloatOf, rhs: BigFloatOf) {
        lhs = lhs - rhs
    }
    public static func += (lhs: inout BigFloatOf, rhs: BigFloatOf) {
        lhs = lhs + rhs
    }
    public static func * (lhs: BigFloatOf, rhs: BigFloatOf) -> BigFloatOf {
        if lhs.isNaN || rhs.isNaN { return .nan }
        if lhs.isInfinite   { return rhs.isZero ? .nan : lhs.sign != rhs.sign ? -.infinity : +.infinity }
        if rhs.isInfinite   { return lhs.isZero ? .nan : lhs.sign != rhs.sign ? -.infinity : +.infinity }
        if lhs.isZero       { return rhs.isInfinite ? .nan : lhs.sign != rhs.sign ? -.zero : +.zero     }
        if rhs.isZero       { return lhs.isInfinite ? .nan : lhs.sign != rhs.sign ? -.zero : +.zero     }
        return BigFloatOf(scale: lhs.scale + rhs.scale, mantissa: lhs.mantissa * rhs.mantissa)
    }
    public static func *= (lhs: inout BigFloatOf, rhs: BigFloatOf) {
        lhs = lhs * rhs
    }
}
// now we have + and -.  Let's make it Strideable
extension BigFloatOf: Strideable {
    public func distance(to other: BigFloatOf) -> BigFloatOf {
        return other - self
    }
    public func advanced(by n: BigFloatOf) -> BigFloatOf {
        return self + n
    }
}
// now it is FloatingPoint
extension BigFloatOf : FloatingPoint {
    public func divided(by other:BigFloatOf,
                        precision px:Int=Self.precision,
                        round rule:FloatingPointRoundingRule=Self.roundingRule)->BigFloatOf
    {
        // easy!  -- and in `IntType` the whole way: the ratio never leaves the
        // element type the mantissa is stored in.
        return BigFloatOf(self.toRational()/other.toRational(), precision:px, round:rule)
    }
    public mutating func divide(by other:BigFloatOf,
                                precision px:Int=Self.precision,
                                round rule:FloatingPointRoundingRule=Self.roundingRule)
    {
        self = self.divided(by: other, precision:px, round:rule)
    }
    public static func / (lhs: BigFloatOf, rhs: BigFloatOf) -> BigFloatOf {
        return lhs.divided(by:rhs)
    }
    public static func /= (lhs: inout BigFloatOf, rhs: BigFloatOf) {
        lhs = lhs / rhs
    }
    public init(signOf: BigFloatOf, magnitudeOf: BigFloatOf) {
        self = signOf.sign == .minus ? -magnitudeOf : +magnitudeOf
    }
    public static var radix: Int { return 2 }
    public static var pi: BigFloatOf { return BigFloatOf.PI(precision:Self.precision) }
    public static var greatestFiniteMagnitude: BigFloatOf { return 0 }
    public static var leastNormalMagnitude: BigFloatOf    { return 0 }
    public static var leastNonzeroMagnitude: BigFloatOf   { return 0 }
    public var ulp: BigFloatOf { return 0 }
    public func quotientAndRemainder(dividingBy other: BigFloatOf,
                                     precision px:Int=Self.precision,
                                     round rule:FloatingPointRoundingRule=Self.roundingRule)
      -> (quotient:BigFloatOf, remainder:BigFloatOf) {
        let (q, r) = self.toRational().quotientAndRemainder(dividingBy: other.toRational())
        return (quotient:BigFloatOf(q), remainder:BigFloatOf(r, precision:px, round:rule))
    }
    public func truncatingRemainder(dividingBy other: BigFloatOf,
                                    precision px:Int=Self.precision,
                                    round rule:FloatingPointRoundingRule=Self.roundingRule)->BigFloatOf
    {
        return self.quotientAndRemainder(dividingBy:other, precision:px, round:rule).quotient
    }
    public mutating func formTruncatingRemainder(dividingBy other: BigFloatOf) {
        self = self.quotientAndRemainder(dividingBy: other).quotient
    }
    public func remainder(dividingBy other: BigFloatOf,
                          precision px:Int=Self.precision,
                          round rule:FloatingPointRoundingRule=Self.roundingRule)->BigFloatOf
    {
        return self.quotientAndRemainder(dividingBy:other, precision:px, round:rule).remainder
    }
    public mutating func formRemainder(dividingBy other: BigFloatOf) {
        self = self.quotientAndRemainder(dividingBy: other).remainder
    }
    public func squareRoot(precision px:Int=Self.precision,
                           round rule:FloatingPointRoundingRule=Self.roundingRule) -> BigFloatOf
    {
        if self.isNaN || self.isLess(than:0) { return .nan }
        if self.isZero { return self }
        return BigFloatOf(self.toRational().squareRoot(precision:px), precision:px, round:rule)
    }
    public func squareRoot(precision px:Int=Self.precision)->BigFloatOf {
        return self.squareRoot(precision:px, round:Self.roundingRule)
    }
    public mutating func formSquareRoot(precision px:Int=Self.precision,
                                        round rule:FloatingPointRoundingRule=Self.roundingRule)
    {
        self = self.squareRoot(precision:px, round:rule)
    }
    public mutating func formSquareRoot() {
        self = self.squareRoot()
    }
    public mutating func addProduct(_ lhs: BigFloatOf, _ rhs: BigFloatOf) {
        self += lhs * rhs
    }
    public var nextUp: BigFloatOf {
        return self
    }
}
// and finally
extension BigFloatOf : BigFloatingPoint {
    public init(_ value: BigRat) {
        self.init(value, precision:Self.precision, round:Self.roundingRule)
    }
    public static func getEpsilon(precision: Int) -> BigFloatOf {
        return BigFloatOf(scale:-Swift.abs(precision), mantissa:1)
    }
    public func toMixed()->(IntType, BigFloatOf) {
        let (i, f) = self.toRational().toMixed()
        return (i, BigFloatOf(f))
    }
    public static func % (_ lhs: BigFloatOf, _ rhs: BigFloatOf) -> BigFloatOf {
        return lhs.remainder(dividingBy: rhs)
    }
}
// Custom{,Debug}StringConvertible
extension BigFloatOf: CustomStringConvertible, CustomDebugStringConvertible {
    public var description:String {
        var s = self.toString()
        if s.first == "+" { s.removeFirst() }
        return s
    }
    /// A `BigFloatOf` debugs as significand-and-exponent, which is how it is
    /// stored -- see `BigNum.Format.exponent`.
    public var debugDescription:String {
        return self.toString(.exponent)
    }
    public init?<S:StringProtocol>(_ str:S, radix:Int=10) {
        self = 0
        // Every exit below is `nil` or a value -- a failable initializer that
        // traps on malformed input is no use to a caller who is asking *whether*
        // the text is a number.  `chars[0]` after a `removeFirst()`, and the two
        // force-unwrapped exponents, used to crash on "+", "00", "1e", "0x1pz"
        // and anything else with a stray "e" in it, "nonsense" included.
        var chars = [Character](str.lowercased())
        guard !chars.isEmpty else { return nil }
        var base   = radix
        var scale  = 0
        var factor = BigFloatOf(1)
        var signum = BigFloatOf(+1.0)
        if      chars.first == "+" { signum = +1.0 ; chars.removeFirst() }
        else if chars.first == "-" { signum = -1.0 ; chars.removeFirst() }
        // one sign only: the significand goes through `IntType(_:radix:)`, which
        // would happily read a second one and cancel this one out
        guard let head = chars.first, head != "+", head != "-" else { return nil }
        if head == "0" {
            chars.removeFirst()
            if chars.isEmpty { self = signum < 0 ? .negativeZero : .zero ; return }
            switch chars[0] {
            case "x" : base = 16 ; chars.removeFirst()
            case "o" : base =  8 ; chars.removeFirst()
            case "b" : base =  2 ; chars.removeFirst()
            default  :
                while chars.first == "0" { chars.removeFirst() }
                if chars.isEmpty { self = signum < 0 ? .negativeZero : .zero ; return }
            }
            guard !chars.isEmpty else { return nil }    // a prefix and nothing else
        }
        // `p` counts powers of two after a hex significand, `e` powers of ten
        // after a decimal one.  Neither applies in the other radices.
        let marker:Character? = base == 16 ? "p" : (base == 10 ? "e" : nil)
        if let marker = marker, let i = chars.firstIndex(of:marker) {
            let tail = String(chars[chars.index(after:i)...])
            chars.removeSubrange(i...)
            if base == 16 {
                guard let e = Exponent(tail) else { return nil }
                scale = e
            } else {
                guard let e = IntType(tail) else { return nil }
                factor = BigFloatOf(base).power(e)
            }
        }
        var dlen = 0
        if let i = chars.firstIndex(of:".") {
            dlen = chars.count - i - 1
            chars.remove(at:i)
        }
        guard let n = IntType(String(chars), radix:base) else { return nil }
        let d = IntType(base).power(dlen)
        self = signum * factor * BigFloatOf(scale:scale, mantissa:1) *  BigFloatOf(n.over(d))
    }
}
extension String {
    /// `public` to match the `BigInt` and `BigUInt` overloads; without it this
    /// was unreachable from outside the module, which cannot have been the intent.
    public init<I>(_ bf:BigFloatOf<I>, radix:Int=10, uppercase:Bool=false){
        let s = bf.toString(.point, radix:radix)
        self = uppercase ? s.uppercased() : s
    }
}

#if swift(>=5.5)
extension BigFloatOf: Sendable { }
#endif
