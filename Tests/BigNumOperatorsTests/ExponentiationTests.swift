import Testing
import BigNumOperators

///
/// `**` forwards and nothing else, so every test here is "the operator agrees
/// with the call it stands for".  What is worth pinning is the parsing: which
/// overload a literal picks, and how the precedence group binds.
///
/// That this module exists at all is the feature -- `2 ** 3` does not compile
/// against `import BigNum` alone.  A unit test cannot assert a compile failure,
/// so that half is checked by building a file that tries it.
///
/// **Every floating-point operand below is explicitly typed, and must stay that
/// way.**  Inside a `#expect` the `FloatLiteralType = Double` default does not
/// apply, so an all-literal `4.0 ** 0.5 == 2.0` is free to resolve to any `Real`
/// -- and it picks `BigFloat`, whose `pow(4, 0.5)` is a 128-bit approximation
/// that prints as "2.0" and compares unequal to 2.  The test then fails while
/// reporting `(4.0 ** 0.5 → 2.0) == 2.0`, which is as confusing as it sounds.
/// Annotating the type is not defensive style here; it is the difference between
/// testing `Double` and testing something else.  The same macro also cannot
/// expand a custom operator alongside `&&`, so conditions are one per `#expect`.
///
@Suite struct ExponentiationTests {

    @Test func integersForwardToPower() {
        #expect(2 ** 10 == 1024)
        #expect(2 ** 10 == Int(2).power(10))
        #expect(Int(-2) ** 3 == -8)
        #expect(UInt8(3) ** 5 == 243)
        #expect(UInt(2) ** 63 == 9223372036854775808)
        #expect(Int8(11) ** 2 == 121)
        #expect(Int32(7) ** 3 == 343)
        // BigInt and BigUInt, where nothing overflows
        #expect(BigInt(2) ** 256 == BigInt(2).power(256))
        #expect((BigInt(2) ** 256).description.count == 78)
        #expect(BigUInt(2) ** 128 == BigUInt(1) << 128)
        #expect(BigInt(-2) ** 255 == -(BigInt(2) ** 255))
        // The edges `power` already has.  One condition per #expect on purpose:
        // the swift-testing macro cannot expand a custom operator alongside `&&`
        // -- `#expect(2 ** 1 == 2 && 2 ** 2 == 4)` does not compile, though the
        // same expression outside a macro parses correctly.
        #expect(Int(5) ** 0 == 1)
        #expect(Int(5) ** 1 == 5)
        #expect(Int(5) ** -2 == 0, "no integral reciprocal, as power(_:) says")
        #expect(BigInt(1) ** -9 == 1)
        #expect(BigInt(-1) ** -9 == -1)
    }

    @Test func floatingPointForwardsToPow() {
        let two: Double = 2.0, nine: Double = 9.0, half: Double = 0.5
        #expect(two ** half == Double.pow(2.0, 0.5))
        #expect(two ** half == two.squareRoot())
        #expect(two ** 10 == 1024.0)
        #expect(two ** 10 == Double.pow(2.0, 10))
        #expect(nine ** half == 3.0)
        // the arbitrary-precision Reals forward to their own pow
        #expect(BigRat(2) ** 10 == BigRat.pow(BigRat(2), 10))
        #expect(BigFloat(2) ** 10 == BigFloat.pow(BigFloat(2), 10))
        #expect(BigFloat(2) ** BigFloat(0.5) == BigFloat.pow(BigFloat(2), BigFloat(0.5)))
        #expect(BigRat(2) ** 10 == 1024)
        #expect(BigFloat(2) ** 10 == 1024)
    }

    /// `**` on a `Real` is `pow`, and `pow` on these types rounds to `precision`
    /// bits.  It is *not* repeated multiplication, which matters most where you
    /// would least expect it: on `BigRat`, whose `*` is exact.
    @Test func realExponentiationRoundsAndIsNotRepeatedMultiplication() {
        // exact, because a power-of-two denominator survives truncation
        #expect(BigRat(1,2) ** 3 == BigRat(1,8))
        #expect(BigRat(2) ** 10 == 1024)
        // not exact, because 1/9 does not
        #expect(BigRat(1,3) * BigRat(1,3) == BigRat(1,9), "multiplication is exact")
        #expect(BigRat(1,3) ** 2 != BigRat(1,9), "pow is not -- it rounds to 128 bits")
        #expect(BigRat(1,3) ** 2 == BigRat.pow(BigRat(1,3), 2), "and `**` is exactly that pow")
        #expect(BigRat(1,3) ** 2 == BigRat(1,3).power(2), "which is power(_:precision:)")
        // near enough to be a rounding difference and no more
        let err = (BigRat(1,3) ** 2 - BigRat(1,9)).magnitude
        #expect(err < BigRat.getEpsilon(precision: 120), "\(err) should be a 128-bit rounding")
        // BigFloat rounds too, and prints as though it had not
        #expect(BigFloat.pow(BigFloat(4), BigFloat(0.5)).description == "2.0")
        #expect(BigFloat.pow(BigFloat(4), BigFloat(0.5)) != 2, "which is worth knowing")
    }

    /// Which overload a bare literal picks.  `2 ** 3` has four candidates -- Int
    /// or Double base, Int or Double exponent -- and the default literal type has
    /// to settle it, or the call is ambiguous.
    @Test func literalsResolveWithoutAnnotation() {
        // bound to a `let` first, which is where the ordinary literal defaults
        // apply -- see the note on this suite about doing it inside #expect
        let i = 2 ** 3
        #expect(i == 8)
        #expect(type(of: i) == Int.self, "an all-integer literal expression is Int")
        let d = 2.0 ** 3
        #expect(d == 8.0)
        #expect(type(of: d) == Double.self, "and an all-float one is Double")
        let e = 2.0 ** 3.0
        #expect(type(of: e) == Double.self)
        #expect(e == 8.0)
        // explicit types on either side still resolve
        let big: BigInt = 2
        #expect(big ** 10 == 1024)
        let rat: BigRat = 2
        #expect(rat ** 10 == 1024)
        let f: BigFloat = 2
        #expect(f ** 10 == 1024)
    }

    /// Right associative and tighter than `*`, which is the whole reason to
    /// declare a precedence group rather than reuse an existing one.
    @Test func precedenceAndAssociativity() {
        #expect(2 ** 3 ** 2 == 512, "right associative: 2 ** (3 ** 2)")
        #expect(2 ** 3 ** 2 != 64, "not (2 ** 3) ** 2")
        #expect(2 * 3 ** 2 == 18, "tighter than *: 2 * (3 ** 2)")
        #expect(3 ** 2 * 2 == 18)
        #expect(1 + 2 ** 3 == 9, "tighter than +")
        #expect(2 ** 3 + 1 == 9)
        #expect(-2 ** 2 == 4, "prefix minus binds tighter in Swift, unlike Python's -4")
        #expect(Int(-2) ** 2 == 4)
        #expect(-(2 ** 2) == -4, "which is how to say the other thing")
        #expect(2 ** 2 ** 3 == 256, "2 ** 8")
        #expect(BigInt(2) ** 2 ** 3 == 256, "and the same for BigInt")
    }

    /// The operator is a forwarder, so it inherits every semantic of the thing it
    /// forwards to -- including the ones that trap.  Those are checked by running
    /// them out of process; here we pin the boundary just inside.
    @Test func inheritsThePropertiesOfWhatItForwardsTo() {
        #expect(Int(2) ** 62 == 4611686018427387904, "the largest power of two an Int holds")
        #expect(BigInt(2) ** 1024 == BigInt(1) << 1024, "no ceiling here")
        // floating point rounds, exact arithmetic does not
        #expect(BigFloat(1) / BigFloat(3) * 3 != 1)
        #expect(BigRat(1) / BigRat(3) * 3 == 1)
    }
}
