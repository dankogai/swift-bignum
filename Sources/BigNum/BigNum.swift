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
    func truncated(width:Int)->Self
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
