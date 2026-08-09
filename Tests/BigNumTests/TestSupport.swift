@testable import BigNum

#if compiler(<6.0)
extension BigRational : DoubleConvertible {}
extension BigFloat: DoubleConvertible {}
#else
extension BigRational : @retroactive DoubleConvertible {}
extension BigFloat: @retroactive DoubleConvertible {}
#endif

/// Rounding is only interesting at the ties and just off them.
let roundingDoubles:[Double] = [-2.5, -1.5, -0.5, -0.2, -0.0, +0.0, 0.2, 0.5, 1.5, 2.5]

let allRoundingRules:[FloatingPointRoundingRule] = [
    .awayFromZero, .down, .toNearestOrAwayFromZero, .toNearestOrEven, .towardZero, .up
]

