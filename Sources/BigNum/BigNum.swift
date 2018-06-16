@_exported import BigInt // imported and re-exported
import FloatingPointMath

///
/// Placeholder for utility functions and values
///
public class BigNum {}

///
/// BigFloatingPoint protocol.
///
public protocol BigFloatingPoint : FloatingPoint, ExpressibleByFloatLiteral, FloatingPointMath {
    associatedtype IntType:SignedInteger
    func squareRoot(precision: Int)->Self
    init(_:BigInt)
    init(_:BigRat)
    init(_:Double)
    init(_:IntType)
    mutating func truncate(width:Int, round:FloatingPointRoundingRule)
    static func %(_:Self,_:Self)->Self
    static func getEpsilon(precision: Int)->Self
    static var maxExponent:Int { get }
    static var precision:Int { get }
    static var roundingRule: FloatingPointRoundingRule { get }
    var asBigRat:BigRat { get }
    var asDouble:Double { get }
    var asMixed:(IntType, Self) { get }
    var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:Self) { get }
    static var ATAN1:(precision: Int, value:Self) { get set }
    static var E:    (precision: Int, value:Self) { get set }
    static var SQRT2:(precision: Int, value:Self) { get set }
    static var LN2:  (precision: Int, value:Self) { get set }
    static var LN10: (precision: Int, value:Self) { get set }
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
}
extension BigFloatingPoint where Self:BinaryFloatingPoint {
    /// decompose to sign, exponent and significand
    public var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:Self) {
        return (sign:self.sign, exponent:self.exponent, significand:self.significand)
    }
    /// truncate does nothing for BinaryFloatingPoint
    public mutating func truncate(width:Int, round:FloatingPointRoundingRule) {}
    /// breaks it down to int part and float part
    public var asMixed:(IntType, Self) {
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
    /// max exponent is set to  = 0x3fff
    public static var maxExponent:Int { return Int(Self.greatestFiniteMagnitude.exponent) }
    /// get epsilon for math functions.  always smaller than 63
    public static func getEpsilon(precision px: Int)->Self {
        return 1.0 / Self(BigInt(1) << min(Self.precision, Swift.abs(px)))
    }
}

public protocol DoubleConvertible {
    init(_:Double)
    var asDouble:Double { get }
}

extension Double: DoubleConvertible {}
extension Float:  DoubleConvertible {}

extension DoubleConvertible {
    init<T:BigFloatingPoint>(_ bf:T) {
        self = Self(bf.asDouble)
    }
}

//
extension BigInt {
    //
    public mutating func truncate(width:Int, round:FloatingPointRoundingRule = .toNearestOrAwayFromZero) {
        let w = Swift.abs(width)
        if self.bitWidth-1 < w { return }
        let t = self.bitWidth-1 - w
        var i = self >> t
        let r = self - (i << t)
        let s = self.signum()
        let a = Swift.abs(r) * 2
        let o = BigInt(1 << t)
        switch round {
        case .toNearestOrAwayFromZero:  i += o <= a ? s : 0
        case .toNearestOrEven:          i += o < a || o == a && i & 1 == 1 ? s : 0
        case .awayFromZero:             i += o < a ?  s : 0
        case .down:                     i += r < 0 ? -1 : 0
        case .up:                       i += 0 < r ? +1 : 0
        case .towardZero:               i += 0
        }
        self = i << t
    }
    public func truncated(width:Int, round:FloatingPointRoundingRule = .toNearestOrAwayFromZero)->BigInt {
        var result = self
        result.truncate(width:width, round:round)
        return result
    }
}
