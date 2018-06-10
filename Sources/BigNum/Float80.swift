/// conforming to BigFloatingPoint
extension Float80: BigFloatingPoint {
    public typealias IntType = Int
    /// does nothing since it is fixed-width
    public func truncated(width:Int)->Float80 { return self }
    /// does nothing since it is fixed-width
    public mutating func truncate(width:Int) {}
    /// just returns sign, exponent, and significand all at once
    public var decomposed:(sign:FloatingPointSign, exponent:Exponent, significand:Float80) {
        return (sign:self.sign, exponent:self.exponent, significand:self.significand)
    }
    /// max exponent is 16383 = 0x3fff
    public static let maxExponent = 0x3fff
    /// BigRat -> Float80
    public init(_ bq: BigRat) { self = bq.asFloat80 }
    /// Float80 -> Double
    public var asDouble:Double { return Double(self) }
    /// Float80 -> BigRat
    public var asBigRat:BigRat { return BigRat(self) }
    /// Truncating Remainder
    public static func %(_ lhs:Float80, _ rhs:Float80)->Float80 {
        return lhs.truncatingRemainder(dividingBy: rhs)
    }
    /// breaks it down to int part and float part
    public var asMixed:(IntType, Float80) {
        let rem = self.truncatingRemainder(dividingBy: 1.0)
        return (IntType(self - rem), rem)
    }
    /// default precision = 63
    public static var defaultPrecision:Int { return 63 }
    /// get epsilon for math functions.  always smaller than 63
    public static func getEpsilon(precision px: Int)->Float80 {
        return 1.0 / Float80(1 << min(63, px.magnitude))
    }
    /// √self . currently delegated to BigRat
    public func squareRoot(precision px: Int) -> Float80 {
        return self.asBigRat.squareRoot(precision: px).asFloat80
    }
}
/// Float80-related extension
extension BigRat {
    /// Float80 -> BigRat
    public init(_ r:Float80) {
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
            let n = (r.sign == .minus ? -1 : +1) * BigInt(r.significand * Float80(1 << Float80.significandBitCount))
            let d = 1 << Float80.significandBitCount
            if (r.exponent < 0) {
                self.init(Element(n), Element(d) << -r.exponent)
            } else {
                self.init(Element(n) << r.exponent,  Element(d))
            }
        }
    }
    /// BigRat -> Float80
    public var asFloat80:Float80 {
        if self.isNaN {
            return Float80.nan
        }
        if self.isZero {
            return self.sign == .minus ? -0.0 : +0.0
        }
        if self.isInfinite {
            return self.sign == .minus ? -Float80.infinity : +Float80.infinity
        }
        let r = Float80(BigInt(num)) / Float80(BigInt(den))
        if r.isZero {       // we know it is not zero so try again with subnormal handling
            let w = Swift.min(den.trailingZeroBitCount, den.bitWidth - 16384)
            return Float80(BigInt(num)) / Float80(BigInt(den >> w)) / Float80(BigInt(1) << w)
        }
        if r.isInfinite {   // we know it is not infinite so try with integral part
            return Float80(BigInt(self.asMixed.0))
        }
        return r
    }
}
