//: [Previous](@previous)
/*:
 # BigInt and BigUInt

 Ordinary `SignedInteger` and `UnsignedInteger` conformances — everything you can
 do to an `Int`, minus the overflow.  See [BigInt.md](BigInt.md) for the details.
 */
import BigNum

//: ## Construction
BigInt(42)
BigInt(1) << 100
let literal: BigInt = 123456789
BigInt("123456789012345678901234567890")!
BigInt("deadbeef", radix:16)!
BigInt("-1010", radix:2)!
BigInt("nonsense")                  // nil -- genuinely failable
BigInt(Double.pi)                   // 3, truncated toward zero
BigInt(exactly: 2.5)                // nil, not an integer

//: ## No overflow
BigInt(Int.max) + 1
BigInt(Int.max) * BigInt(Int.max)
(1 ... 30).reduce(BigInt(1)) { $0 * BigInt($1) }     // 30! = 265252859812191058636308480000000

//: ## Division truncates toward zero, remainder follows the dividend
BigInt(7)  / BigInt(2)
BigInt(-7) / BigInt(2)
BigInt(-7) % BigInt(2)
BigInt(7)  % BigInt(-2)
BigInt(-7).quotientAndRemainder(dividingBy: 2)

//: ## Two's complement, so the bit operators mean what they do for Int
~BigInt(5)
BigInt(-6) & BigInt(3)
BigInt(-6) | BigInt(3)
BigInt(-6) ^ BigInt(3)

//: `>>` is arithmetic: it floors, and never runs out of sign bits
BigInt(-5) >> 1                     // -3, floor(-2.5)
BigInt(-1) >> 100                   // -1, not 0
BigInt(1)  >> 100                   //  0
BigInt(1)  << -3                    //  a negative count reverses direction

//: You can see the representation
Array(BigInt(1).words)
Array(BigInt(-1).words)
Array(BigInt(UInt(1) << 63).words)  // a clear sign limb goes on top

//: ## Widths.  bitWidth counts the magnitude's bits plus one for the sign
BigInt(0).bitWidth
BigInt(1).bitWidth
BigInt(-1).bitWidth
BigInt(255).bitWidth
BigUInt(255).bitWidth               // no sign bit here
BigInt(-48).trailingZeroBitCount    // negation does not move trailing zeros

//: ## Number theory
BigInt(2).power(64).squareRoot()
BigInt(10).squareRoot()                             // floor(sqrt(10))
BigInt(1071).greatestCommonDivisor(with: 462)
BigInt(-12).greatestCommonDivisor(with: 18)         // always non-negative

//: A Mersenne prime candidate, and its digit count
let m127 = BigInt(2).power(127) - 1
m127                                // 170141183460469231731687303715884105727
m127.description.count              // 39 digits

//: ## Strings and conversions
BigInt(255).toString(radix:16)
BigInt(255).toString(radix:16, uppercase:true)
BigInt(255).toString(radix:2)
String(BigInt(255), radix:8)
Double(BigInt(1) << 100)
Double(BigInt(1) << 2000)           // inf, like any Double that overflows
Int(BigInt(-7))

//: ## BigUInt
BigUInt(1) << 128
BigUInt(1) << 128 - 1
~BigUInt(0xff)                      // complement within the bits it occupies
BigInt(-5).magnitude                // a BigUInt
BigUInt("-1")                       // nil -- unsigned refuses a sign

//: ## And a BigRat falls out of two integers
BigInt(1).over(3)
BigInt(6).over(4)                   // reduced on construction

//: [Next](@next)
