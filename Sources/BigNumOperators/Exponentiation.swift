//
//  Exponentiation.swift -- the `**` operator, for those who want it.
//
//  This is a module of its own so that it stays off unless asked for:
//
//      import BigNum                 // no ** in sight
//      import BigNumOperators        // ** available, BigNum re-exported
//
//  Swift has no submodules, so `import BigNum.operators` is not a spelling that
//  can be built.  `import Module.Decl` does parse -- it is a scoped import, and
//  what it scopes is declarations, not operators -- so it could not gate this
//  either.  A separate module is the mechanism the language actually offers, and
//  it gates cleanly: an operator declaration is visible only to files that import
//  the module declaring it.
//
//  `**` is not in the standard library on purpose, and the reasons are worth
//  knowing before you turn it on:
//
//   *  There is no exponentiation precedence group, so this file declares one.
//      Two modules that each declare their own and disagree cannot be imported
//      into the same file.
//   *  Swift binds prefix `-` tighter than any infix operator, so `-2 ** 2` is
//      `(-2) ** 2`, which is 4.  Python says -4.  There is no fixing this from
//      here; write `-(2 ** 2)` when you mean it.
//
//  What it forwards to, and nothing more:
//
//      2 ** 10                  // Int.power(10)      -- 1024
//      BigInt(2) ** 256         // BigInt.power(256)  -- exact
//      2.0 ** 0.5               // Double.pow(2, 0.5) -- 1.4142135623730951
//      BigRat(1,3) ** 2         // BigRat.pow(x, 2)   -- rounded, see below
//
//  So every rule those carry, `**` carries.  An integer `**` traps on overflow
//  the way `*` does, and a negative integer exponent gives 0 for anything but
//  ±1.  On a `Real` it is `pow`, which rounds to `precision` bits -- and that is
//  worth spelling out for `BigRat`, whose `*` does not:
//
//      BigRat(1,3) * BigRat(1,3)   // (1/9), exact
//      BigRat(1,3) ** 2            // 1/9 rounded to 128 bits, which is not (1/9)
//      BigRat(1,2) ** 3            // (1/8) -- exact, but only because the
//                                  //   denominator is already a power of two
//
//  `**` is not repeated multiplication on those types.  Reach for `*`, or for
//  `pow(_:_:precision:)`, when the rounding is the thing you care about.
//

@_exported import BigNum

/// Binds tighter than `*`, and to the right, so `2 ** 3 ** 2` is `2 ** 9`.
/// Both match ordinary mathematical notation, and Python.
precedencegroup ExponentiationPrecedence {
    associativity: right
    higherThan: MultiplicationPrecedence
}

infix operator ** : ExponentiationPrecedence

// MARK: - integers: b.power(e)

/// `Int`, `UInt`, `Int8` ... `UInt64`, `Int128`.  Traps on overflow, as `power`
/// and `*` both do -- `2 ** 1024` is not a number an `Int` has.
public func ** <T:FixedWidthInteger>(_ base: T, _ exponent: Int) -> T {
    return base.power(exponent)
}

/// `BigInt` and `BigUInt`, where nothing overflows.
public func ** <T:BigIntegerType>(_ base: T, _ exponent: Int) -> T {
    return base.power(exponent)
}

// MARK: - floating point: pow(b, e)

/// `Double`, `BigRat` and `BigFloat` -- every `Real`.  The arbitrary-precision
/// two work to `Self.precision` bits; call `pow(_:_:precision:)` directly when you
/// want to say how many.
public func ** <T:Real>(_ base: T, _ exponent: T) -> T {
    return T.pow(base, exponent)
}

/// An integer exponent, which is exact where the general form would iterate: this
/// is `pow(x, n)`, not `pow(x, T(n))`.
public func ** <T:Real>(_ base: T, _ exponent: Int) -> T {
    return T.pow(base, exponent)
}
