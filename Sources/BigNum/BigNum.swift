import BigInt
@_exported import struct BigInt.BigInt  // re-export BigInt

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
    var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:Self) { get }
    static var maxExponent:Int { get }
    var asDouble:Double { get }
    var asMixed:(BigInt, Self) { get }
    static func %(_:Self,_:Self)->Self
}
