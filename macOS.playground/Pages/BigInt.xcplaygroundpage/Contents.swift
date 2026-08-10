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

//: ## Modular exponentiation -- `power(_:mod:)`, Python's three-argument `pow()`.
//: Intermediates are reduced as they are formed, so nothing ever grows past
//: twice the modulus's width.
BigInt(2).power(10, mod: 1000)                      // 24
BigInt(123456789).power(12345, mod: 1000000007)
BigInt(2).power(1000000, mod: 7)    // instant; `power(1000000) % 7` would not be

//: The result takes the sign of the modulus -- a floored remainder, where `%`
//: gives a truncated one
BigInt(-2).power(3, mod: 5)         //  2
BigInt(-2).power(3) % 5             // -3, the same value in the other convention
BigInt(2).power(3, mod: -5)         // -2

//: A negative exponent raises the modular inverse
BigInt(2).power(-1, mod: 5)         // 3, because 2*3 == 6 ≡ 1 (mod 5)
BigInt(3).power(-3, mod: 7)         // 6
//: BigInt(2).power(-1, mod: 4)     // would trap: 2 and 4 share a factor

//: The exponent can be a BigInt too, which is what a Fermat test needs.  If
//: m127 were composite this would almost certainly not be 1.
BigInt(3).power(m127 - 1, mod: m127)            // 1
BigInt(3).power(BigInt(1) << 100, mod: 1000000007)

//: ## Primality.  `isPrime` is a Bool? -- nil means "not proven", never "no"
BigInt(1000003).isPrime                         // true
BigInt(1000001).isPrime                         // false, 101 * 9901
BigInt(561).isPrime                             // false -- a Carmichael number
m127.isPrime                                    // true, since Lucas-Lehmer settles it
(BigInt(1) << 300).nextPrime.isPrime            // nil -- probably prime, unproven

//: At or below UInt64.max it is never nil -- that range is exhaustively
//: verified -- so for numbers that size the force unwrap cannot trap
BigInt(1000003).isPrime!                        // true
BigInt(UInt64.max).isPrime!                     // false
BigInt(-7).isPrime!                             // false

//: The probable answer is still there under its own name, and `isSurelyPrime`
//: hands back both halves.  A composite is provable at any size; a prime needs
//: to be below 2^64, below A014233's last entry, or a Mersenne number.
(BigInt(1) << 300).nextPrime.isProbablePrime    // true, where isPrime said nil
BigInt(65537).isSurelyPrime                     // (true, surely: true)
BigInt(561).isSurelyPrime                       // (false, surely: true)
(BigInt(1) << 300).nextPrime.isSurelyPrime      // (true, surely: false)

//: Both halves of BPSW pull their weight: 2047 == 23 * 89 slips past Miller-Rabin
//: on base 2, and only the Lucas test catches it
BigInt(2047).millerRabinTest(base: 2)           // true
BigInt(2047).isLucasProbablePrime               // false
BigInt(7).jacobiSymbol(3)                       // -1

//: A Mersenne number has an exact test -- and `nil` means "not 2^p - 1 at all",
//: which is not the same answer as `false`
m127.isMersennePrime                            // true
(BigInt(1) << 523 - 1).isMersennePrime          // false
BigInt(100).isMersennePrime                     // nil

//: Walking the primes.  nextPrime needs no Optional: there is no ceiling here.
BigInt(1000).nextPrime                          // 1009
(BigInt(1) << 64).nextPrime                     // 18446744073709551629
(BigInt(1) << 64).prevPrime                     // 18446744073709551557
BigInt(2).prevPrime                             // nil
Array(BigInt.primes.prefix(10))

/*:
 ## All of the above, on the built-in integers

 `Int`, `UInt`, `Int8` ... `UInt64` and `Int128` get every one of these.  Each
 widens to `BigInt`, works there, and comes back -- so an answer that does not
 fit traps, just as `*` would.
 */
Int(2).power(10)                                // 1024
1000003.isPrime!                                // true -- never nil at this width
UInt8(200).nextPrime                            // 211
Int(1071).greatestCommonDivisor(with: 462)      // 21
UInt(4611686018427387904).squareRoot()          // 2147483648
Array(Int.primes.prefix(5))                     // [2, 3, 5, 7, 11]

//: The modular form cannot overflow -- the answer is bounded by the modulus,
//: which is an Int already.  `power(_:) % m` could not manage this.
Int(2).power(1024, mod: 1_000_000_007)          // 812734592
UInt8(200).power(200, mod: 251)                 // 1, where 200*200 overflows a UInt8
//: Int(2).power(1024)                          // would trap: an Int has no such number
//: Int8(127).nextPrime                         // would trap: 131 does not fit

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

/*:
 ## `over`: a fraction out of two integers

 The type you call it on decides the rational you get, which is how you pick
 between arithmetic that can grow and arithmetic that cannot.
 */
BigInt(1).over(3)                   // a BigRat
BigInt(6).over(4)                   // reduced on construction
BigInt(6).over(-4)                  // the sign moves to the numerator
1.over(3)                           // an IntRat -- 1 is an Int
Int8(1).over(2)                     // a FixedWidthRational<Int8>
Int64(3).over(9)                    // a FixedWidthRational<Int64>

//: No special cases needed for the special values
BigInt(1).over(0)                   // infinity
BigInt(0).over(0)                   // NaN
BigInt(0).over(5)                   // zero, normalized

//: 355/113, the classic approximation, exactly and then as a Double
BigInt(355).over(113)
BigInt(355).over(113).toDouble()

//: [Next](@next)
