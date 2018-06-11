import BigInt
@_exported import struct BigInt.BigInt  // re-export BigInt
import FloatingPointMath

///
/// Placeholder for utility functions and values
///
public class BigNum {}

///
/// BigFloatingPoint protocol.
///
public protocol BigFloatingPoint : FloatingPoint, ExpressibleByFloatLiteral {
    associatedtype IntType:SignedInteger
    func squareRoot(precision: Int)->Self
    init(_:BigInt)
    init(_:BigRat)
    init(_:Double)
    init(_:IntType)
    mutating func truncate(width:Int)
    static func %(_:Self,_:Self)->Self
    static func getEpsilon(precision: Int)->Self
    static var defaultPrecision:Int { get }
    static var maxExponent:Int { get }
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
    public func truncated(width px: Int)->Self {
        var result = self
        result.truncate(width: px)
        return result
    }
}
extension BigFloatingPoint where Self:BinaryFloatingPoint {
    /// decompose to sign, exponent and significand
    public var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:Self) {
        return (sign:self.sign, exponent:self.exponent, significand:self.significand)
    }
    /// truncate does nothing for BinaryFloatingPoint
    public mutating func truncate(width:Int) {}
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
    public static var defaultPrecision:Int { return Self.significandBitCount }
    /// max exponent is set to  = 0x3fff
    public static var maxExponent:Int { return Int(Self.greatestFiniteMagnitude.exponent) }
    /// get epsilon for math functions.  always smaller than 63
    public static func getEpsilon(precision px: Int)->Self {
        return 1.0 / Self(BigInt(1) << min(defaultPrecision, Swift.abs(px)))
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
