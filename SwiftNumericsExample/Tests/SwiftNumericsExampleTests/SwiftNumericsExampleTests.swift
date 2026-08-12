import Testing
import BigNum
import ComplexModule
import Foundation
@testable import SwiftNumericsExample

///
/// `Complex<BigRat>` and `Complex<BigFloat>`, which is the point of this package.
///
/// The conformances are two empty `extension`s, because BigNum declares the five
/// members that would otherwise tie on its concrete types -- see the end of
/// Real.swift.  What is worth checking from this side is that the tie really is
/// broken, so the five are exercised below through a file that imports both
/// hierarchies: an ambiguity would be a build failure, and a witness that had come
/// to call itself would be a test run that never returns.
///
@Suite struct ConformanceTests {

    /// The five, called from a file that can see both `Real`s.
    @Test func theTieBreakersResolveAndAgreeWithBigNum() {
        // sqrt
        #expect(BigRat.sqrt(BigRat(4)) == 2)
        #expect(BigFloat.sqrt(BigFloat(4)) == 2)
        // √2 against BigNum's own answer at BigNum's default precision.  128 is
        // written out because *reading* `BigRat.precision` is an error under Swift 6
        // strict concurrency -- it is a mutable `static var`.
        //
        // Compared by subtraction, not `==`: for `BigFloat` those two carry the same
        // number in different mantissa widths, and `BigFloat.==` looks at the storage.
        // See `bigFloatEqualityLooksAtStorageNotValue` below.
        #expect(BigRat.sqrt(BigRat(2)) == BigRat.SQRT2(precision: 128))
        #expect((BigFloat.sqrt(BigFloat(2)) - BigFloat.SQRT2(precision: 128)).isZero)
        // exp10
        #expect(BigRat.exp10(BigRat(2)) == 100)
        #expect(BigFloat.exp10(BigFloat(3)) == 1000)
        // reciprocal -- exact for a rational
        #expect(BigRat(4).reciprocal == BigRat(1, 4))
        #expect(BigFloat(4).reciprocal == BigFloat(0.25))
        #expect(BigRat.zero.reciprocal?.isInfinite == true, "zero has a reciprocal where there is an infinity")
        // signGamma: Γ is negative between the odd negative integers
        #expect(BigRat.signGamma(BigRat(3)) == .plus)
        #expect(BigRat.signGamma(BigRat(-1, 2)) == .minus, "-0.5 lies in (-1, 0)")
        #expect(BigRat.signGamma(BigRat(-3, 2)) == .plus, "-1.5 lies in (-2, -1)")
        #expect(BigRat.signGamma(BigRat(-5, 2)) == .minus)
        #expect(BigRat.signGamma(BigRat(-2)) == .plus, "a pole, not a sign change")
        #expect(BigFloat.signGamma(BigFloat(-0.5)) == .minus)
        #expect(BigFloat.signGamma(BigFloat(-1.5)) == .plus)
        // and it agrees with Double's, which comes from the same logic
        for x in [3.0, -0.5, -1.5, -2.5, -2.0, 0.0, 7.25, -7.25] {
            #expect(BigFloat.signGamma(BigFloat(x)) == (tgamma(x) < 0 ? .minus : .plus), "signGamma(\(x))")
        }
        // division
        #expect(BigRat(1) / BigRat(4) == BigRat(1, 4))
        #expect(BigRat(-7) / BigRat(2) == BigRat(-7, 2))
        // `Double` conforms to both `Real`s as well, and the same four are at stake.
        // swift-numerics declares `exp10` concretely on `Double` and BigNum leaves
        // that one to it; BigNum declares the other three.  All four resolve.
        #expect(Double.sqrt(4.0) == 2.0)
        #expect(Double.exp10(2.0) == 100.0)
        #expect(Double.signGamma(-0.5) == .minus)
        #expect(4.0.reciprocal == 0.25)
    }

    /// Exact where `Double` cannot be: a rational's `/` divides rather than rounds.
    @Test func rationalDivisionStaysExact() {
        let third = BigRat(1) / BigRat(3)
        #expect(third * 3 == 1, "1/3 * 3 == 1 exactly, which no binary float manages")
        #expect(BigRat(1, 10) + BigRat(2, 10) == BigRat(3, 10), "0.1 + 0.2 == 0.3")
        #expect(0.1 + 0.2 != 0.3, "as Double, famously, does not")
    }
}

///
/// The arithmetic, over both types, checked against values that are exact in binary
/// so that agreement is agreement and not luck.
///
@Suite struct ComplexTests {

    @Test func arithmeticOverBigRat() {
        let a = Complex<BigRat>(1, 2)
        let b = Complex<BigRat>(3, 4)
        #expect(a + b == Complex<BigRat>(4, 6))
        #expect(a - b == Complex<BigRat>(-2, -2))
        #expect(a * b == Complex<BigRat>(-5, 10))
        #expect(Complex<BigRat>.i * Complex<BigRat>.i == Complex<BigRat>(-1, 0), "i² == -1")
    }

    @Test func arithmeticOverBigFloat() {
        let a = Complex<BigFloat>(1, 2)
        let b = Complex<BigFloat>(3, 4)
        #expect(a + b == Complex<BigFloat>(4, 6))
        #expect(a - b == Complex<BigFloat>(-2, -2))
        #expect(a * b == Complex<BigFloat>(-5, 10))
        #expect(Complex<BigFloat>.i * Complex<BigFloat>.i == Complex<BigFloat>(-1, 0), "i² == -1")
    }

    /// Division is where an exact type earns its keep: (1+2i)/(3+4i) is
    /// (11+2i)/25 = 0.44 + 0.08i, and neither 0.44 nor 0.08 is a binary fraction.
    @Test func divisionIsExactOverBigRat() {
        let q = Complex<BigRat>(1, 2) / Complex<BigRat>(3, 4)
        #expect(q == Complex<BigRat>(BigRat(11, 25), BigRat(2, 25)),
                "got \(q.real.toString()) + \(q.imaginary.toString())i")
        // and it round-trips, which a rounding division would not
        #expect(q * Complex<BigRat>(3, 4) == Complex<BigRat>(1, 2))
        // `Double` has no 11/25 to land on -- 25 is not a power of two -- so its
        // answer is the nearest Double to 0.44 and not the number itself.
        // Converting back to an exact rational is what shows it; the round trip
        // does *not*, because this particular multiply happens to round back.
        let qd = Complex<Double>(1, 2) / Complex<Double>(3, 4)
        #expect(BigRat(qd.real) != BigRat(11, 25), "Double's 0.44 is not 11/25")
        #expect(BigRat(qd.imaginary) != BigRat(2, 25), "nor its 0.08 2/25")
        #expect(qd * Complex<Double>(3, 4) == Complex<Double>(1, 2),
                "it does round-trip here, which is luck rather than exactness")
    }

    /// Both types agree with `Double` on values a `Double` represents exactly.
    @Test func agreesWithDoubleWhereDoubleIsExact() {
        for (re, im) in [(1.0, 2.0), (-3.0, 0.5), (0.0, -1.0), (2.5, -4.25)] {
            let zr = Complex<BigRat>(BigRat(re), BigRat(im))
            let zf = Complex<BigFloat>(BigFloat(re), BigFloat(im))
            let zd = Complex<Double>(re, im)
            let w = Complex<Double>(1.5, -2.0)
            let wr = Complex<BigRat>(BigRat(1.5), BigRat(-2.0))
            let wf = Complex<BigFloat>(BigFloat(1.5), BigFloat(-2.0))
            #expect((zr * wr).real.toDouble() == (zd * w).real, "real of product at \(re),\(im)")
            #expect((zr * wr).imaginary.toDouble() == (zd * w).imaginary)
            #expect((zf * wf).real.toDouble() == (zd * w).real)
            #expect((zf * wf).imaginary.toDouble() == (zd * w).imaginary)
        }
    }

    /// The transcendentals, which is what needed `Real` rather than just a field.
    /// `exp(iπ) == -1` is the check that reaches all the way down to `ATAN1`.
    @Test func transcendentalsOverBigFloat() {
        let pi = BigFloat.pi
        let z = Complex<BigFloat>.exp(Complex<BigFloat>(0, pi))
        // 128 bits, so a hair either side of -1 rather than exactly it
        let tol = BigFloat.getEpsilon(precision: 100)
        #expect((z.real - (-1)).magnitude < tol, "Re exp(iπ) = \(z.real), want -1")
        #expect(z.imaginary.magnitude < tol, "Im exp(iπ) = \(z.imaginary), want 0")
        // √i = (1+i)/√2
        let root = Complex<BigFloat>.sqrt(Complex<BigFloat>.i)
        let half = BigFloat.sqrt(BigFloat(2)) / 2
        #expect((root.real - half).magnitude < tol)
        #expect((root.imaginary - half).magnitude < tol)
        // log(e) == 1
        let one = Complex<BigFloat>.log(Complex<BigFloat>(BigFloat.exp(1), 0))
        #expect((one.real - 1).magnitude < tol)
    }

    /// The reason to want this over `Complex<Double>`: precision that does not run
    /// out.  Even at BigNum's default 128 bits, `exp(iπ)` lands far closer to -1
    /// than a `Double` can express.
    ///
    /// Raising the precision would show more, and cannot be demonstrated here:
    /// `BigFloat.precision = 512` is an error in Swift 6 language mode, because it
    /// is a mutable `static var`.  Reading it is an error too.
    @Test func precisionGoesFurtherThanDouble() {
        let z = Complex<BigFloat>.exp(Complex<BigFloat>(0, BigFloat.pi))
        let zd = Complex<Double>.exp(Complex<Double>(0, Double.pi))
        // Double: sin(π) is ~1.22e-16 away from 0 and cannot be closer
        #expect(zd.imaginary.magnitude > 1e-17, "Double's error in Im exp(iπ)")
        #expect(zd.imaginary.magnitude < 1e-15)
        // BigFloat at 128 bits: past where a Double has any bits left
        #expect(z.imaginary.magnitude < BigFloat.getEpsilon(precision: 100))
        #expect(BigFloat.getEpsilon(precision: 100).toDouble() < 1e-30,
                "the bar just cleared is below anything a Double can express")
    }
}

///
/// A defect in BigNum that this exercise turned up, in both `BigFloat` and `BigRat`,
/// now fixed in both.  It matters here because `Complex` compares its `RealType`.
///
@Suite struct EqualityAcrossRepresentations {

    /// `BigFloat.==` used to be `isIdentical(to:)` -- `scale` and `mantissa` -- which
    /// made two spellings of one number unequal and left `<`, `==` and `>` all false,
    /// something `Comparable` forbids.  It compares values now.
    ///
    /// It matters here because `Complex` compares its `RealType`.
    @Test func bigFloatComparesValuesNotStorage() {
        let a = BigFloat.sqrt(BigFloat(2))          // 129-bit mantissa
        let b = BigFloat.SQRT2(precision: 128)      // 641 bits, low 512 of them zero
        #expect((a - b).isZero, "the same number, two representations")
        #expect(a.description == b.description, "and they print the same")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(!(a === b), "`===` still reports the storage differs")
        #expect([a < b, a == b, a > b].filter { $0 }.count == 1, "exactly one holds")
    }

    /// `BigRat` had the same defect and the same fix.  On its own terms the type was
    /// always sound -- it reduces on construction -- but `BigRat(someBigFloat)` builds
    /// `mantissa / 2^-scale` without reducing, and `init(num:den:)` stores whatever it
    /// is given.  `==` cross-multiplies now.
    @Test func bigRatComparesValuesNotFractions() {
        let ra = BigRat(BigFloat.sqrt(BigFloat(2)))
        let rb = BigRat(BigFloat.SQRT2(precision: 128))
        #expect((ra - rb).isZero, "the same number")
        #expect(ra.den.bitWidth != rb.den.bitWidth, "129 bits against 641")
        #expect(ra == rb)
        #expect(ra.hashValue == rb.hashValue)
        #expect(!ra.isIdentical(to: rb), "and the fractions still differ")
        #expect([ra < rb, ra == rb, ra > rb].filter { $0 }.count == 1, "exactly one holds")
        // sound where it always was
        #expect(BigRat(2, 4) == BigRat(1, 2))
        #expect(BigRat(1, 3) + BigRat(1, 6) == BigRat(1, 2))
    }
}

/// The demo entry points, so that what the README shows is what runs.
@Suite struct DemoTests {
    @Test func demoFunctionsAgreeWithTheirComments() {
        let (q, roundTrips) = exactComplexDivision()
        #expect(q.real == BigRat(11, 25) && q.imaginary == BigRat(2, 25))
        #expect(roundTrips)
        let (bf, d) = eulerIdentity()
        #expect((bf.real + 1).magnitude.toDouble() < 1e-38, "about 1e-39, per the comment")
        #expect(bf.imaginary.magnitude.toDouble() < 1e-38)
        #expect(d.imaginary.magnitude > 1e-17 && d.imaginary.magnitude < 1e-15, "1.22e-16")
        let r = squareRootOfI()
        #expect(r.real.toDouble() == 0.7071067811865476)
        #expect(r.imaginary.toDouble() == 0.7071067811865476)
        demo()
    }
}
