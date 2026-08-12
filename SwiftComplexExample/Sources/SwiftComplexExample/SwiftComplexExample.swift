//
//  SwiftComplexExample.swift -- BigNum and dankogai/swift-complex together.
//
//  Everything here is asserted in the test suite, so the comments are checked
//  rather than claimed.
//
import BigNum
import Complex

/// Complex division over an *exact* type.
///
/// `(1+2i)/(3+4i)` is `(11+2i)/25` -- 0.44 + 0.08i -- and 25 is not a power of two,
/// so no binary float lands on either component.  Over `BigRat` the answer is the
/// number itself, and multiplying back returns exactly what you started with.
public func exactComplexDivision() -> (quotient: Complex<BigRat>, roundTrips: Bool) {
    let q = Complex<BigRat>(1, 2) / Complex<BigRat>(3, 4)
    return (q, q * Complex<BigRat>(3, 4) == Complex<BigRat>(1, 2))
}

/// `exp(iπ) == -1` at whatever precision you ask for.
///
/// This is the part SwiftNumericsExample cannot do.  swift-numerics' `Complex` has
/// no precision parameter, so it runs at whatever `BigFloat.precision` says -- and
/// under Swift 6 language mode that static cannot even be read, let alone set.
/// swift-complex threads `precision:` through every function, so a caller picks the
/// width at the call site and no global is involved.
public func eulerIdentity(precision px: Int) -> Complex<BigFloat> {
    return Complex<BigFloat>.exp(Complex<BigFloat>(0, BigFloat.PI(precision: px)),
                                 precision: px, debug: false)
}

/// How far `exp(iπ)` lands from -1, as a `Double`, for each width.  Reporting it as
/// a `Double` runs out before the arithmetic does: at 1024 bits the miss is 9.2e-309,
/// already a subnormal.
public func precisionLadder(_ widths: [Int] = [128, 256, 512]) -> [(bits: Int, error: Double)] {
    return widths.map { px in
        let z = eulerIdentity(precision: px)
        return (px, ((z.real + 1).magnitude + z.imag.magnitude).toDouble())
    }
}

/// √i = (1+i)/√2, over `BigFloat`.
public func squareRootOfI() -> Complex<BigFloat> {
    return Complex<BigFloat>.sqrt(Complex<BigFloat>(0, 1))
}

/// Prints the four above.  `swift test` is where the checking is.
public func demo() {
    let (q, roundTrips) = exactComplexDivision()
    print("Complex<BigRat>: (1+2i)/(3+4i) = \(q.real.toString()) + \(q.imag.toString())i")
    print("                exact 11/25 and 2/25? \(q.real == BigRat(11, 25) && q.imag == BigRat(2, 25))")
    print("                multiplies back exactly? \(roundTrips)")
    for (bits, error) in precisionLadder([128, 256, 512, 1024]) {
        print("Complex<BigFloat>: exp(iπ) at \(bits) bits misses -1 by \(error)")
    }
    let d = Complex<Double>.exp(Complex<Double>(0, Double.pi))
    print("Complex<Double>:   exp(iπ) misses -1 by \((d.real + 1).magnitude + d.imag.magnitude)")
    let r = squareRootOfI()
    print("Complex<BigFloat>: √i = \(r.real.toDouble()) + \(r.imag.toDouble())i")
}
