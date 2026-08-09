/*:
 # swift-bignum

 Arbitrary-precision arithmetic for Swift, in Swift — with **no dependencies**.
 `import BigNum` is the only import you need; `BigInt` comes with it.

 Four types:

 - `BigInt`   — signed integer, arbitrary width, two's complement
 - `BigUInt`  — unsigned counterpart
 - `BigRat`   — *exact* rational, `BigInt` over `BigInt`
 - `BigFloat` — binary floating point with an arbitrary mantissa

 Pages: [BigInt](BigInt) · [BigRat](BigRat) · [BigFloat](BigFloat) ·
 [Precision](Precision) · [Scratch](Scratch)
 */
import BigNum

//: ## Integers that do not overflow
BigInt(2).power(256)
BigInt(Int.max) * BigInt(Int.max)
BigInt("123456789012345678901234567890")!

//: ## Rationals that are exact
BigRat(1,3) + BigRat(1,3) + BigRat(1,3) == 1    // true
0.1 + 0.2 == 0.3                                 // false, for a Double
BigRat(1,10) + BigRat(2,10) == BigRat(3,10)      // true

//: ## Floating point with as many bits as you ask for
BigFloat.sqrt(2)
BigFloat.sqrt(2, precision:256)

//: ## And no overflow where the answer exists
Double.exp(1000)                    // inf
BigFloat.exp(1000).description      // all 435 digits of it

//: ## The difference between the two real types
BigRat(1)/BigRat(3)     * 3 == 1    // true  -- exact
BigFloat(1)/BigFloat(3) * 3 == 1    // false -- rounded to `precision` bits

//: [Next](@next)
