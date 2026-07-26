import Foundation
@testable import BigNum

#if compiler(<6.0)
extension BigRational : DoubleConvertible {}
extension BigFloat: DoubleConvertible {}
#else
extension BigRational : @retroactive DoubleConvertible {}
extension BigFloat: @retroactive DoubleConvertible {}
#endif

/// Every interesting corner of a `Double`, and nothing else:
/// NaN, both zeros, both infinities, ±1 (where most series expansions
/// change their branch), the ulp neighbourhood of 1, a subnormal,
/// and the extremes of the exponent range.
let edgeDoubles:[Double] = [
    .nan,
    -0.0, +0.0,
    -.infinity, +.infinity,
    -1.0, +1.0,
    -0.5, +0.5,
    -2.0, +2.0,
    1 - Double.ulpOfOne/2, 1 + Double.ulpOfOne,
    -Double.ulpOfOne, +Double.ulpOfOne,
    -1024.0, +1024.0,
    -1/Double.greatestFiniteMagnitude, +1/Double.greatestFiniteMagnitude,
    -Double.greatestFiniteMagnitude, +Double.greatestFiniteMagnitude,
]

/// Rounding is only interesting at the ties and just off them.
let roundingDoubles:[Double] = [-2.5, -1.5, -0.5, -0.2, -0.0, +0.0, 0.2, 0.5, 1.5, 2.5]

let allRoundingRules:[FloatingPointRoundingRule] = [
    .awayFromZero, .down, .toNearestOrAwayFromZero, .toNearestOrEven, .towardZero, .up
]

/// Compares an arbitrary-precision result `rq` against `Double`'s `rd`.
/// Returns `nil` when they agree, or the reason they do not.
///
/// - `ulp`: how many `Double` ulps of relative error to forgive.
/// - `unless`: an escape hatch for inputs `Double` cannot represent the
///   answer to at all -- typically `f(f⁻¹(x)) == x` or a known overflow.
func mismatch<R:BigFloatingPoint>(
    _ rd:Double, _ rq:R, ulp:Int, unless ok:Bool = false
) -> String? {
    if rq.isNaN || rd.isNaN {
        return rd.isNaN == rq.isNaN ? nil
            : "expected \(rd.debugDescription), got \(rq.asDouble.debugDescription)"
    }
    // BigNum has no overflow so it stays finite where Double gives up
    if rd.isInfinite  { return nil }
    if rq.isInfinite  { return "expected \(rd.debugDescription), got \(rq.asDouble)" }
    let qrd = R(rd)
    if qrd == rq { return nil }
    if ok        { return nil }
    let tolerance = R(Double(ulp) * .ulpOfOne)
    // a *relative* error is meaningless where the answer is zero, as it is at
    // logGamma(1) and logGamma(2); fall back to an absolute one
    if qrd.isZero {
        return Swift.abs(rq) <= tolerance ? nil
            : "!~ 0 // got \(rq.asDouble.debugDescription)"
    }
    // NOTE: divide by the *magnitude*. The old suite divided by the signed
    // result, which turned every negative answer's error negative and so let it
    // past any tolerance unchecked -- that is what hid the expMinusOne() bug.
    let err = Swift.abs(qrd - rq) / Swift.abs(rq)
    if err <= tolerance { return nil }
    return "!~ \(rd.debugDescription) // err=\(String(format:"%a", err.asDouble))"
}
