import Testing
import BigNum
import Complex
@testable import SwiftComplexExample

///
/// `Complex<BigRat>` and `Complex<BigFloat>` over dankogai/swift-complex.
///
/// The conformances are two empty extensions, so the interesting question is not
/// whether they compile but whether the arithmetic that results is BigNum's.
/// swift-complex 5.0.0 would compile these too and then compute every
/// transcendental in `Double`, silently, because its protocol supplies the
/// functions as extension defaults routed through `asDouble` instead of declaring
/// them as requirements.  Most of what follows exists to catch that.
///
@Suite struct ConformanceTests {

    /// The one that matters.  If the witnesses were swift-complex's Double-routed
    /// defaults rather than BigNum's own functions, this error would be 1.2e-16 --
    /// exactly what `Complex<Double>` gives -- instead of about 1e-39.
    @Test func transcendentalsUseBigNumAndNotDouble() {
        let z = eulerIdentity(precision: 128)
        let err = ((z.real + 1).magnitude + z.imag.magnitude).toDouble()
        #expect(err < 1e-38, "exp(iπ) at 128 bits misses -1 by \(err)")
        #expect(err > 0, "and it is not exactly -1 either")
        let d = Complex<Double>.exp(Complex<Double>(0, Double.pi))
        let derr = ((d.real + 1).magnitude + d.imag.magnitude)
        #expect(derr > 1e-17 && derr < 1e-15, "Double's own miss, for contrast: \(derr)")
        #expect(err < derr / 1e20, "BigNum's answer is many orders better, not equal")
    }

    /// `precision:` is threaded through, so the width is a call-site decision and no
    /// global is touched -- which is what SwiftNumericsExample could not manage under
    /// Swift 6 language mode.
    @Test func precisionIsACallSiteDecision() {
        let ladder = precisionLadder([128, 256, 512])
        #expect(ladder.count == 3)
        // each doubling of the width squares the accuracy, roughly
        #expect(ladder[0].error < 1e-38 && ladder[0].error > 1e-40, "128 bits: \(ladder[0].error)")
        #expect(ladder[1].error < 1e-76 && ladder[1].error > 1e-78, "256 bits: \(ladder[1].error)")
        #expect(ladder[2].error < 1e-154 && ladder[2].error > 1e-156, "512 bits: \(ladder[2].error)")
        #expect(ladder[0].error > ladder[1].error && ladder[1].error > ladder[2].error)
        // at 1024 bits the miss is a *subnormal* Double -- 9.2e-309, past the
        // 2.2e-308 where normal Doubles stop -- so reporting it as one is already
        // stretching the messenger
        let far = precisionLadder([1024])[0]
        #expect(far.error < 1e-300, "1024 bits: \(far.error)")
        #expect(far.error > 0, "and not quite zero yet")
    }

    /// Names that were ambiguous against swift-complex 5.0.0 -- whose protocol
    /// extension defaulted about two dozen functions -- resolve here, because `main`
    /// declares them as requirements instead.
    @Test func theFunctionNamesAreNotAmbiguous() {
        #expect(BigRat.exp(0) == 1)
        #expect(BigFloat.sqrt(BigFloat(4)) == 2)
        #expect(BigRat.log(1) == 0)
        #expect((BigFloat.cos(BigFloat(0)) - 1).isZero)
        #expect(BigRat.hypot(3, 4) == 5)
        #expect((BigFloat.atan2(y: 0, x: 1)).isZero)
        // Double keeps working too: swift-complex routes it through a marker protocol
        // so that its witnesses do not collide with BigNum's concrete ones
        #expect(Double.exp(0.0) == 1.0)
        #expect(Double.sqrt(4.0) == 2.0)
    }
}

///
/// The arithmetic, over both types, on values that are exact in binary so agreement
/// is agreement rather than luck.
///
@Suite struct ComplexTests {

    @Test func arithmeticOverBothTypes() {
        let a = Complex<BigRat>(1, 2), b = Complex<BigRat>(3, 4)
        #expect(a + b == Complex<BigRat>(4, 6))
        #expect(a - b == Complex<BigRat>(-2, -2))
        #expect(a * b == Complex<BigRat>(-5, 10))
        let f = Complex<BigFloat>(1, 2), g = Complex<BigFloat>(3, 4)
        #expect(f + g == Complex<BigFloat>(4, 6))
        #expect(f - g == Complex<BigFloat>(-2, -2))
        #expect(f * g == Complex<BigFloat>(-5, 10))
        // i² == -1, spelled with swift-complex's `.i` on a real
        #expect(BigRat(1).i * BigRat(1).i == Complex<BigRat>(-1, 0))
    }

    /// Division over an exact type is exact: (1+2i)/(3+4i) is (11+2i)/25, and
    /// neither 0.44 nor 0.08 is a binary fraction.
    @Test func divisionIsExactOverBigRat() {
        let (q, roundTrips) = exactComplexDivision()
        #expect(q.real == BigRat(11, 25) && q.imag == BigRat(2, 25),
                "got \(q.real.toString()) + \(q.imag.toString())i")
        #expect(roundTrips)
        // Double has no 11/25 to land on -- 25 is not a power of two
        let qd = Complex<Double>(1, 2) / Complex<Double>(3, 4)
        #expect(BigRat(qd.real) != BigRat(11, 25), "Double's 0.44 is not 11/25")
    }

    @Test func squareRootOfIIsTheExpectedOne() {
        let r = squareRootOfI()
        #expect(r.real.toDouble() == 0.7071067811865476)
        #expect(r.imag.toDouble() == 0.7071067811865476)
        // and squaring it returns i, to the precision in play
        let sq = r * r
        #expect(sq.real.magnitude < BigFloat.getEpsilon(precision: 100))
        #expect((sq.imag - 1).magnitude < BigFloat.getEpsilon(precision: 100))
    }

    /// Both types agree with `Double` where a `Double` is exact.
    @Test func agreesWithDoubleWhereDoubleIsExact() {
        for (re, im) in [(1.0, 2.0), (-3.0, 0.5), (0.0, -1.0), (2.5, -4.25)] {
            let w = Complex<Double>(1.5, -2.0)
            let zd = Complex<Double>(re, im) * w
            let zr = Complex<BigRat>(BigRat(re), BigRat(im)) * Complex<BigRat>(BigRat(1.5), BigRat(-2.0))
            let zf = Complex<BigFloat>(BigFloat(re), BigFloat(im))
                       * Complex<BigFloat>(BigFloat(1.5), BigFloat(-2.0))
            #expect(zr.real.toDouble() == zd.real && zr.imag.toDouble() == zd.imag, "BigRat at \(re),\(im)")
            #expect(zf.real.toDouble() == zd.real && zf.imag.toDouble() == zd.imag, "BigFloat at \(re),\(im)")
        }
    }
}

/// The demo entry points, so that what the comments show is what runs.
@Suite struct DemoTests {
    @Test func demoAgreesWithItsComments() {
        demo()
    }
}
