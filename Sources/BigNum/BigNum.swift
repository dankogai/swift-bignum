
///
/// Placeholder for utility functions and values
///
public class BigNum {}

extension BigNum {
    ///
    /// How `toString(_:radix:)` should render a value.
    ///
    public enum Format : Sendable {
        /// Positional, with a radix point: `+1.41421356237309504876`.  Enough
        /// digits to carry the value's own precision, and no radix prefix.
        case point
        /// The ratio it actually is: `(+3260954456333195553/2305843009213693952)`,
        /// or `(+0x2d413cccfe779921/0x2000000000000000)` in radix 16.
        case fraction
        /// Significand and binary exponent, the way C's `%a` prints a `double`:
        /// `+0x1.6a09e667f3bcc908p0`.  Hexadecimal by definition -- the `p`
        /// counts bits, so `radix` does not apply and is ignored.
        case exponent
    }

    /// The prefix that announces a radix, for the radices that have one.
    internal static func radixPrefix(_ radix:Int)->String {
        switch radix {
        case 2:     return "0b"
        case 8:     return "0o"
        case 16:    return "0x"
        default:    return ""
        }
    }
}

///
/// BigFloatingPoint protocol.
///
public protocol BigFloatingPoint : ExpressibleByFloatLiteral, Real {
    associatedtype IntType:SignedInteger
    func squareRoot(precision: Int)->Self
    init(_:BigInt)
    init(_:BigRat)
    init(_:Double)
    init(_:IntType)
    mutating func truncate(width:Int, round:FloatingPointRoundingRule)
    func divided(by:Self, precision:Int, round:FloatingPointRoundingRule)->Self
    func remainder(dividingBy:Self, precision:Int,  round:FloatingPointRoundingRule)->Self
    static func %(_:Self,_:Self)->Self
    static func getEpsilon(precision: Int)->Self
    static var expLimit:Self { get set }
    static var precision:Int { get }
    static var roundingRule: FloatingPointRoundingRule { get }
    func toBigRat()->BigRat
    func toDouble()->Double
    func toMixed()->(IntType, Self)
    var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:Self) { get }
}
extension BigFloatingPoint {
    public mutating func truncate(width px:Int) {
        self.truncate(width:px, round:Self.roundingRule)
    }
    public func truncated(width px:Int=Self.precision, round rule:FloatingPointRoundingRule=Self.roundingRule)->Self {
        var result = self
        result.truncate(width:px, round:rule)
        return result
    }
    public func divided(by other:Self, precision px:Int)->Self {
        return self.divided(by:other, precision:px, round:Self.roundingRule)
    }
    public func divided(by other:Self)->Self {
        return self.divided(by:other, precision:Self.precision, round:Self.roundingRule)
    }
    public mutating func divide(by other:Self, precision px:Int, round rule:FloatingPointRoundingRule=Self.roundingRule) {
        self = self.divided(by:other, precision:px, round:Self.roundingRule)
    }
    /// Every arbitrary-precision value renders through `BigRat`, which is the one
    /// type that can hold any of them exactly.
    public func toString(_ format:BigNum.Format = .point, radix:Int = 10)->String {
        return self.toBigRat().toString(format, radix:radix)
    }
}
extension BigFloatingPoint where Self:BinaryFloatingPoint {
    /// decompose to sign, exponent and significand
    public var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:Self) {
        return (sign:self.sign, exponent:self.exponent, significand:self.significand)
    }
    /// truncate does nothing for BinaryFloatingPoint
    public mutating func truncate(width:Int, round:FloatingPointRoundingRule) {}
    /// breaks it down to int part and float part
    public func toMixed()->(IntType, Self) {
        let rem = self.truncatingRemainder(dividingBy: 1.0)
        return (IntType(self - rem), rem)
    }
    /// √self . precision is just ignored for BinaryFloatingPoint
    public func squareRoot(precision px: Int) -> Self {
        return self.squareRoot()
    }
    /// Truncating Remainder
    public static func %(_ lhs:Self, _ rhs:Self)->Self {
        return lhs.truncatingRemainder(dividingBy: rhs)
    }
    /// defaultPrecision is set to significandBitCount
    public static var precision:Int { return Self.significandBitCount }
    /// get epsilon for math functions.  always smaller than 63
    public static func getEpsilon(precision px: Int)->Self {
        return 1.0 / Self(BigInt(1) << min(Self.precision, Swift.abs(px)))
    }
}

public protocol DoubleConvertible {
    init(_:Double)
    func toDouble()->Double
}

//extension Double: DoubleConvertible {}
//extension Float:  DoubleConvertible {}
//
//extension DoubleConvertible {
//    init<T:BigFloatingPoint>(_ bf:T) {
//        self = Self(bf.toDouble())
//    }
//}

//
extension SignedInteger {
    //
    public mutating func truncate(width:Int, round:FloatingPointRoundingRule = .toNearestOrAwayFromZero) {
        let w = Swift.abs(width)
        if self.bitWidth-1 < w { return }
        let t = self.bitWidth-1 - w
        var i = self >> t
        let r = self - (i << t)
        let s = self.signum()
        let a = Swift.abs(r) * 2
        let o = Self(1) << t
        switch round {
        case .toNearestOrAwayFromZero:  i += o <= a ? s : 0
        case .toNearestOrEven:          i += o < a || o == a && i & 1 == 1 ? s : 0
        case .awayFromZero:             i += o < a ?  s : 0
        case .down:                     i += r < 0 ? -1 : 0
        case .up:                       i += 0 < r ? +1 : 0
        case .towardZero:               i += 0
                                        @unknown default:               fatalError()
        }
        self = i << t
    }
    public func truncated(width:Int, round:FloatingPointRoundingRule = .toNearestOrAwayFromZero)->Self {
        var result = self
        result.truncate(width:width, round:round)
        return result
    }
}
