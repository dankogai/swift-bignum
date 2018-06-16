/// Skip iOS and watchOS
#if os(iOS) || os(watchOS)
#else
/// conforming to BigFloatingPoint
extension Float80: BigFloatingPoint {
    /// Corresponding integer type
    public typealias IntType = Int
    public static var roundingRule = FloatingPointRoundingRule.toNearestOrAwayFromZero
    /// constants
    public static var ATAN1 = (precision:0, value:nan)
    public static var E     = (precision:0, value:nan)
    public static var SQRT2 = (precision:0, value:nan)
    public static var LN2   = (precision:0, value:nan)
    public static var LN10  = (precision:0, value:nan)
    /// BigRat -> Float80
    public init(_ bq: BigRat) { self = bq.asFloat80 }
    /// Float80 -> Double
    public var asDouble:Double { return Double(self) }
    /// Float80 -> BigRat
    public var asBigRat:BigRat { return BigRat(self) }
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
#endif
