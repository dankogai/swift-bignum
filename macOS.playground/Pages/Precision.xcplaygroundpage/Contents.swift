//: [Previous](@previous)
/*:
 # Precision

 Every lossy operation takes an optional `precision:` in **bits**.  Omit it and the
 type's `precision` static is used, which starts at 128.
 */
import BigNum

//: ## The knob
BigFloat.precision
BigFloat.sqrt(2, precision:32)
BigFloat.sqrt(2, precision:64)
BigFloat.sqrt(2, precision:128)
BigFloat.sqrt(2, precision:1024).description.count   // 311 characters

/*:
 ## Precision bounds the error, not the digits

 A 32-bit √2 prints twenty digits — but only about ten of them are √2's.  The rest
 are the exact expansion of the *approximation*, which is a different number.
 */
BigFloat.sqrt(2, precision:32)
BigFloat.sqrt(2, precision:256)
//: The first ten digits agree; after that they diverge
String(BigFloat.sqrt(2, precision:32).description.prefix(12))
String(BigFloat.sqrt(2, precision:256).description.prefix(12))

//: ## Moving the default
BigRat.precision
BigFloat.precision = 256
BigFloat.sqrt(2)                    // now 256 bits
BigFloat.precision = 128            // put it back

//: ## π to a few different widths
BigFloat.PI(precision:32)
BigFloat.PI(precision:64)
BigFloat.PI(precision:128)
BigRat.PI(precision:128).toString()

/*:
 √2, e, log 2, log 10 and π/4 are memoized per precision, so asking twice at the
 same precision costs nothing the second time.
 */
BigRat.E(precision:128).toString()
BigRat.E(precision:128).toString()  // free
BigRat.E(precision:256).toString()  // recomputed, wider

/*:
 ## Truncating on purpose

 A `BigRat` is exact, so a feedback loop doubles its denominator every step and
 never stops.  Truncating each result holds it flat, at the cost of rounding.
 */
var z = BigRat(1,3)
for _ in 1...5 {
    z = z*z + BigRat(1,7)
    z.den.bitWidth                  // 7, 13, 25, 49, 97 -- doubling
}
z.den.bitWidth                      // 97

var w = BigRat(1,3)
for _ in 1...5 {
    w = (w*w + BigRat(1,7)).truncated(width:32)
    w.den.bitWidth                  // stays around 34
}
w.den.bitWidth                      // 36

//: BigFloat truncation, and what it does to the value
BigFloat.sqrt(2).truncated(width:8).debugDescription
BigFloat.sqrt(2).truncated(width:16).debugDescription
BigFloat.sqrt(2).truncated(width:32).debugDescription

//: ## Epsilon at a given precision
BigFloat.getEpsilon(precision:16)
BigRat.getEpsilon(precision:16)
BigRat.getEpsilon(precision:128).toString(.fraction).count   // 44

//: ## Rounding rules are honoured throughout
for rule in [FloatingPointRoundingRule.down, .up, .towardZero, .toNearestOrEven] {
    print(rule, BigFloat(22).divided(by: BigFloat(7), precision:8, round: rule))
}

//: [Next](@next)
