//: [Previous](@previous)
/*:
 # BigRat

 An exact rational: a `BigInt` over a `BigInt`, always reduced.  It is a
 `FloatingPoint`, but nothing it does rounds unless you ask.
 See [BigRat.md](BigRat.md).
 */
import BigNum

//: ## Exact means exact
BigRat(1,3) + BigRat(1,3) + BigRat(1,3) == 1
0.1 + 0.2 == 0.3                                    // Double says false
BigRat(1,10) + BigRat(2,10) == BigRat(3,10)         // BigRat says true
BigRat(1,3) * 3
BigRat(2,3) / BigRat(4,9)
BigRat(1,3).reciprocal!

//: A sum that a Double gets wrong: 1/1 + 1/2 + ... + 1/10
(1...10).reduce(BigRat.zero) { $0 + BigRat(1, $1) }   // exactly (7381/2520)

//: ## Construction, and one thing to watch
BigRat(1, 3)
BigInt(1).over(3)
BigRat(6, 4)                        // reduced
BigRat(6, -4)                       // the sign moves to the numerator
let one: BigRat = 1
BigRat(0.5)
//: `BigRat(0.1)` is the *exact* value of the Double 0.1 — which is not one tenth
BigRat(0.1)
BigRat(1, 10)                       // this is one tenth

//: ## NaN, the infinities and the two zeros come out of the fraction itself
BigRat.nan.toString(.fraction)              // (+0/0)
BigRat.infinity.toString(.fraction)         // (+1/0)
(-BigRat.infinity).toString(.fraction)      // (-1/0)
BigRat.zero.toString(.fraction)             // (+0/1)
(-BigRat.zero).toString(.fraction)          // (+0/-1) -- the sign is on the denominator
BigRat(0,0).isNaN
BigRat.infinity > 1

//: ## Mixed numbers and rounding
BigRat(22,7).toMixed().0            // BigInt(3)
BigRat(22,7).toMixed().1            // BigRat(1,7)
BigRat(22,7) % 1
BigRat(22,7).rounded()
BigRat(-22,7).rounded(.towardZero)
BigRat(22,7).exponent               // decomposes in radix 2
BigRat(22,7).significand            // normalized to [1,2)

//: ## Keeping a fraction from growing without bound
BigRat.sqrt(2).num.bitWidth         // 129 bits of numerator
BigRat(1,3).truncated(width:8)      // (85/256)
BigRat(1,3).truncated(width:8).toString()

//: ## Elementary functions, at whatever precision you like
BigRat.pi.toString()
BigRat.E().toString()
BigRat.exp(1).toString()
BigRat.log(2).toString()
BigRat.sin(1).toString()
BigRat.hypot(3,4)                   // exact when it can be
BigRat.atan2(y:1,x:1).toString()
BigRat(2).power(10)                 // integer exponent, exact

//: ## Strings
let q = BigRat.sqrt(2)
q.toString()
q.toString(.fraction)
q.toString(.exponent)
q.debugDescription

//: ## Conversions
BigRat(22,7).toDouble()
BigRat(22,7).toBigFloat()
BigRat(22,7).toIntRat()

//: ## The fixed-width rationals, for bounded storage
IntRat(1,3)
IntRat(1,3) + IntRat(1,6)
IntRat.max
Rational<BigInt>(1,3)

//: [Next](@next)
