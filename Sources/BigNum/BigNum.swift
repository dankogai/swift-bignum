import BigInt
@_exported import struct BigInt.BigInt  // re-export BigInt
import FloatingPointMath

///
/// Placeholder for utility functions and values
///
public class BigNum {}

public protocol BigFloatingPoint : FloatingPoint, ExpressibleByFloatLiteral {
    associatedtype IntType:SignedInteger
    func truncated(width:Int)->Self
    mutating func truncate(width:Int)
    func squareRoot(precision: Int)->Self
    init(_:Double)
    init(_:BigInt)
    init(_:IntType)
    init(_:BigRat)
    var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:Self) { get }
    static var maxExponent:Int { get }
    var asDouble:Double { get }
    var asMixed:(IntType, Self) { get }
    var asBigRat:BigRat { get }
    static func %(_:Self,_:Self)->Self
    static var defaultPrecision:Int { get }
    static func getEpsilon(precision: Int)->Self
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
