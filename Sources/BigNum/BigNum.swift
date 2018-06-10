import BigInt
@_exported import struct BigInt.BigInt  // re-export BigInt

///
/// Placeholder for utility functions and values
///
public class BigNum {}

public protocol BigFloatingPoint : FloatingPoint, ExpressibleByFloatLiteral {
    func truncated(width:Int)->Self
    mutating func truncate(width:Int)
    func squareRoot(precision: Int)->Self
    init(_:Double)
}
