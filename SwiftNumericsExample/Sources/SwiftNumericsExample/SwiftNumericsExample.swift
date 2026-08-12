//
//  SwiftNumericsExample.swift -- BigNum and apple/swift-numerics together.
//
//  What this package is for: `Complex<BigRat>` and `Complex<BigFloat>`.
//  NumericsConformance.swift is the part that makes them compile; this file is what
//  they are good for.
//
//  Everything printed here is asserted in the test suite, so the comments are
//  checked rather than claimed.
//
import BigNum
import ComplexModule
// RealModule too, and not only for tidiness: `Complex<Double>` below needs
// `Double: RealModule.Real`, and a conformance is only usable in a file that
// imports the module declaring it.  Without this line the compiler says so --
// "cannot use conformance of 'Double' to 'Real' here".
import RealModule

/// Complex division over an *exact* type.
///
/// `(1+2i)/(3+4i)` is `(11+2i)/25` -- 0.44 + 0.08i -- and 25 is not a power of two,
/// so no binary float lands on either component.  Over `BigRat` the answer is the
/// number itself, and multiplying back returns exactly what you started with.
public func exactComplexDivision() -> (quotient: Complex<BigRat>, roundTrips: Bool) {
    let q = Complex<BigRat>(1, 2) / Complex<BigRat>(3, 4)
    return (q, q * Complex<BigRat>(3, 4) == Complex<BigRat>(1, 2))
}

/// Complex transcendentals at more precision than a `Double` has.
///
/// `exp(iπ) == -1` is the whole chain: `Complex.exp` calls `BigFloat`'s `cos` and
/// `sin`, which reduce by π, which comes from `ATAN1`.  At BigNum's default 128 bits
/// both components land about 1e-39 from where they should be, where a `Double`'s
/// imaginary part is 1.22e-16 out and cannot do better.
public func eulerIdentity() -> (bigFloat: Complex<BigFloat>, double: Complex<Double>) {
    return (Complex<BigFloat>.exp(Complex<BigFloat>(0, BigFloat.pi)),
            Complex<Double>.exp(Complex<Double>(0, Double.pi)))
}

/// √i = (1+i)/√2, over `BigFloat`.
public func squareRootOfI() -> Complex<BigFloat> {
    return Complex<BigFloat>.sqrt(Complex<BigFloat>.i)
}

/// Prints the three above.  Not a test -- `swift test` is where the checking is.
public func demo() {
    let (q, roundTrips) = exactComplexDivision()
    print("Complex<BigRat>: (1+2i)/(3+4i) = \(q.real.toString()) + \(q.imaginary.toString())i")
    print("                exact 11/25 and 2/25? \(q.real == BigRat(11, 25) && q.imaginary == BigRat(2, 25))")
    print("                multiplies back exactly? \(roundTrips)")

    let (bf, d) = eulerIdentity()
    print("Complex<BigFloat>: exp(iπ) off by  re \((bf.real + 1).magnitude.toDouble()), im \(bf.imaginary.magnitude.toDouble())")
    print("Complex<Double>:   exp(iπ) off by  re \((d.real + 1).magnitude), im \(d.imaginary.magnitude)")

    let r = squareRootOfI()
    print("Complex<BigFloat>: √i = \(r.real.toDouble()) + \(r.imaginary.toDouble())i")
}
