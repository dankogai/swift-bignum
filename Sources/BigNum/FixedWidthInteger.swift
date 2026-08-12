//
//  FixedWidthInteger.swift -- BigNum's number theory, on the built-in integers.
//
//  Everything here is one line: widen to `BigInt`, do the work there, and come
//  back.  `Int`, `UInt`, `Int8` ... `UInt64` and -- where the platform has it --
//  `Int128`/`UInt128` all pick these up, since they are written against
//  `FixedWidthInteger` rather than declared per type.
//
//  Delegating rather than reimplementing is the whole point.  A modular exponent
//  needs a product of two residues, which does not fit in a word; a gcd wants
//  in-place limb work; primality wants both of those plus a Lucas sequence.
//  Written natively, each would need an overflow-avoiding variant per width, and
//  a call from a context generic over `FixedWidthInteger` would statically pick
//  whichever the compiler happened to see.  `BigInt` has none of those problems,
//  so it does the arithmetic and the only fixed-width question left is whether
//  the answer fits.
//
//  Which it does not, sometimes -- and then it traps, exactly as `*` and `+` do
//  on these types.  `Int(2).power(1024)` is not a number an `Int` has, and this
//  says so rather than wrapping or clamping:
//
//      Int(2).power(62)                // 4611686018427387904
//      Int(2).power(1024)              // traps: not representable
//      Int8(127).nextPrime             // traps: 131 does not fit
//      Int.min.greatestCommonDivisor(with: Int.min)    // traps: 2^63 does not
//
//  `BigInt` is where to go when that is not what you want -- and it is one
//  `BigInt(x)` away.  The operations that cannot overflow are noted below.
//
//  These are extensions on `FixedWidthInteger` and not on `BinaryInteger` for a
//  reason worth keeping: `BigInt` and `BigUInt` are `BinaryInteger`s, so the
//  wider extension would apply to them too, and `BigInt(self).isPrime` inside it
//  would be at risk of resolving straight back to itself.  `FixedWidthInteger`
//  cannot overlap them, and covers every built-in integer type anyway.
//

// MARK: - exponentiation

extension FixedWidthInteger {
    /// `self` raised to `exponent`, by square-and-multiply in `BigInt`.
    ///
    /// Traps unless the result is representable -- `Int(2).power(1024)` is not a
    /// number an `Int` has.  Use `BigInt(self).power(exponent)` for one that can
    /// hold it.
    public func power<E:BinaryInteger>(_ exponent: E) -> Self {
        return Self(BigInt(self).power(exponent))
    }

    /// `self` raised to `exponent`, reduced modulo `modulus` -- Python's
    /// three-argument `pow()`.  See `BigIntegerType.power(_:mod:)` for the three
    /// conventions it follows; briefly, the result takes the sign of `modulus`, a
    /// negative `exponent` raises the modular inverse, and a zero `modulus` traps.
    ///
    /// This one cannot overflow: the answer is bounded by `modulus`, which is a
    /// `Self` already.  It is the reason to reach for `power(_:mod:)` rather than
    /// `power(_:)` followed by `%`, which would have to build the whole power
    /// first and would trap long before it got there.
    ///
    ///     Int(2).power(1024, mod: 1_000_000_007)      // 812734592
    ///     Int(2).power(1024) % 1_000_000_007          // traps
    ///
    /// One generic overload, with no `Self`-exponent twin like the one
    /// `BigIntegerType` keeps: when `Self` is `Int` the two would be the same
    /// signature, and every call ambiguous.  The generic covers both, and takes a
    /// `BigInt` exponent as well.
    public func power<E:BinaryInteger>(_ exponent: E, mod modulus: Self) -> Self {
        return Self(BigInt(self).power(BigInt(exponent), mod: BigInt(modulus)))
    }
}

// MARK: - roots and divisors, for the unsigned types only
//
// The signed ones have had both of these all along, from `RationalElement` in
// Rational.swift -- `Int(10).squareRoot()` worked before this file existed, and
// by the same widen-and-return trick.  `RationalElement` refines
// `SignedInteger`, though, so `UInt` and its narrower siblings were left out.
// Constraining to `UnsignedInteger` fills that gap without colliding with what
// is already there; an unconstrained extension here makes `Int` ambiguous and
// stops Rational.swift itself from compiling.

extension FixedWidthInteger where Self : UnsignedInteger {
    /// ⌊√self⌋, by Newton's method in `BigInt`.  Cannot overflow: a square root
    /// is never larger than what it came from.
    public func squareRoot() -> Self {
        return Self(BigInt(self).squareRoot())
    }

    /// The greatest common divisor of `self` and `other`, by Stein's binary GCD
    /// in `BigInt`.  Cannot overflow: a divisor of an unsigned value fits
    /// wherever the value did.
    public func greatestCommonDivisor(with other: Self) -> Self {
        return Self(BigInt(self).greatestCommonDivisor(with: BigInt(other)))
    }
}

// MARK: - primality

extension FixedWidthInteger {
    /// Whether `self` is prime, or `nil` when no test here can settle it.
    ///
    /// For a type of 64 bits or fewer this is **never `nil`** -- every value it
    /// can hold is inside the exhaustively verified range -- so `isPrime!` is
    /// safe there and is the natural thing to write:
    ///
    ///     Int(1000003).isPrime!           // true
    ///     UInt64.max.isPrime!             // false
    ///     Int(-7).isPrime!                // false
    ///
    /// A 128-bit type is the one exception: above `UInt64.max` a prime may come
    /// back `nil`, meaning "probably, unproven".  See `BigIntegerType.isPrime`.
    public var isPrime: Bool? {
        return BigInt(self).isPrime
    }

    /// The Baillie-PSW result itself, without the certainty gate -- `true` where
    /// `isPrime` would say `nil`.  Exact for any type of 64 bits or fewer.
    public var isProbablePrime: Bool {
        return BigInt(self).isProbablePrime
    }

    /// Whether `self` is prime, and whether that answer is certain.  For a type
    /// of 64 bits or fewer `surely` is always `true`.
    public var isSurelyPrime: (Bool, surely: Bool) {
        return BigInt(self).isSurelyPrime
    }

    /// `true` if `self` passes the Miller-Rabin test on `base`, which proves
    /// compositeness but never primality.
    public func millerRabinTest(base: Self) -> Bool {
        return BigInt(self).millerRabinTest(base: BigInt(base))
    }

    /// The Jacobi symbol (`i` / `self`), 0 unless `self` is odd and positive.
    public func jacobiSymbol(_ i: Int) -> Int {
        return BigInt(self).jacobiSymbol(i)
    }

    /// `true` if `self` is a Lucas probable prime for the first Selfridge
    /// parameters.
    public var isLucasProbablePrime: Bool {
        return BigInt(self).isLucasProbablePrime
    }

    /// The Lucas-Lehmer test: `true` if `self` is a Mersenne prime, `false` if it
    /// is a composite Mersenne number, `nil` if `self` is not 2^p - 1 at all.
    public var isMersennePrime: Bool? {
        return BigInt(self).isMersennePrime
    }

    /// The first prime greater than `self`.  Traps when there is not one left in
    /// the type -- `Int8(127).nextPrime` would be 131.
    public var nextPrime: Self {
        return Self(BigInt(self).nextPrime)
    }

    /// The last prime less than `self`, or nil when there is none.  Cannot
    /// overflow, since it only ever moves toward zero.
    public var prevPrime: Self? {
        return BigInt(self).prevPrime.map { Self($0) }
    }

    /// The primes from 2 upward, lazily.  Traps if you walk it past `Self.max`,
    /// which for anything wider than an `Int16` means it will not.
    ///
    ///     Array(Int.primes.prefix(5))     // [2, 3, 5, 7, 11]
    public static var primes: some Sequence<Self> {
        return BigInt.primes.lazy.map { Self($0) }
    }
}
