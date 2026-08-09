//: [Previous](@previous)
/*:
 # BigFloat

 Binary floating point with an arbitrary mantissa: a `BigInt` significand and an
 `Int` power-of-two scale.  Many digits, but bounded storage.
 See [BigFloat.md](BigFloat.md).
 */
import BigNum

//: ## Representation: mantissa × 2^scale, normalized
BigFloat(1).mantissa
BigFloat(1).scale
BigFloat(8).scale                       // 3 -- trailing zero bits move to the scale
BigFloat(scale:0, mantissa:4).scale     // 2, for the same reason
BigFloat(scale:0, mantissa:4).mantissa  // 1
BigFloat(scale:-1, mantissa:3)          // 1.5

//: ## BigFloat rounds where BigRat grows
BigRat(1)/BigRat(3)     * 3 == 1        // true  -- exact
BigFloat(1)/BigFloat(3) * 3 == 1        // false -- rounded
(BigFloat(1)/BigFloat(3)).mantissa.bitWidth
BigFloat(1).divided(by: BigFloat(3), precision:16)
BigFloat(1).divided(by: BigFloat(3), precision:16).mantissa.bitWidth

//: Every BigFloat is exactly a BigRat, so that direction loses nothing
BigFloat(0.1).toBigRat().toString(.fraction)
BigFloat(BigRat(1,3))
BigFloat(BigRat(1,3), precision:16)

//: ## Construction, including from text
BigFloat(0.1)                   // the Double's real value, not one tenth
let x: BigFloat = 1.5
BigFloat("1.5")!
BigFloat("0x1.8p1")!            // hex significand, binary exponent
BigFloat("0x1p-4")!
BigFloat("0b1011")!
BigFloat("0o17")!
BigFloat("1.5e10")!
BigFloat("1.8p1", radix:16)!    // the radix argument stands in for a prefix
//: It is genuinely failable
BigFloat("nonsense")
BigFloat("1e")
BigFloat("0x1pz")
BigFloat("--1")

//: ## Precision and rounding
BigFloat.precision
BigFloat.roundingRule
BigFloat.sqrt(2)
BigFloat.sqrt(2, precision:32)  // exact expansion of a value good to 32 bits
BigFloat.sqrt(2, precision:256)
BigFloat.getEpsilon(precision:16)
BigFloat.expLimit               // past this, exp gives infinity rather than running on

//: Truncation cuts a value that has accumulated more bits than you need
BigFloat.sqrt(2).mantissa.bitWidth
BigFloat.sqrt(2).truncated(width:16)
BigFloat.sqrt(2).truncated(width:16).debugDescription

//: ## Equality is IEEE; identity compares the representation
BigFloat(0) == -BigFloat(0)             // true
BigFloat(0) === -BigFloat(0)            // false
BigFloat.nan.isEqual(to: BigFloat.nan)  // false
BigFloat.nan.isIdentical(to: BigFloat.nan)   // true
(-BigFloat(0)).sign

//: ## Specials
BigFloat.nan
BigFloat.infinity
BigFloat.zero.debugDescription
BigFloat.negativeZero.debugDescription
BigFloat(1)/BigFloat(0)
BigFloat(0)/BigFloat(0)

//: ## Elementary functions, and no overflow where the answer exists
BigFloat.pi
BigFloat.log(2)
BigFloat.atan2(y:1, x:1) * 4
BigFloat.cbrt(27)
BigFloat(2).power(BigInt(100))
Double.exp(1000)                        // inf
BigFloat.exp(1000).description.count    // 437 == 435 digits + ".0"

//: ## Strings
BigFloat.sqrt(2).toString()
BigFloat.sqrt(2).toString(.exponent)
BigFloat.sqrt(2).description
BigFloat.sqrt(2).debugDescription
String(BigFloat.sqrt(2), radix:16)

//: [Next](@next)
