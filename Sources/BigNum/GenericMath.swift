public protocol DoubleConvertible {
    var asDouble:Double { get }
}

extension Double: DoubleConvertible { public var asDouble:Double { return self }}
extension Float:  DoubleConvertible { public var asDouble:Double { return Double(self) }}

extension FloatingPoint where Self:DoubleConvertible {
    public var asBigRat : BigRat {
        return self as? BigRat ?? BigRat(self.asDouble)
    }
    public func toFloatingPointString(radix:Int = 10)->String {
        return self.asBigRat.toFloatingPointString(radix:radix)
    }
}

