//: [Previous](@previous)

import BigNum

BigInt(+1).over(+2)
BigInt(+1).over(-2)
BigInt(-1).over(+2)
BigInt(-1).over(-2)

let q:BigRat   = 1
let qpi = BigRat(Double.pi)

BigRat.cos(qpi)
qpi.asMixed
(qpi % 1.0).asDouble

BigRat.E(precision:128)
BigRat.E(precision:-128)
BigRat.E()

BigRat(3, 1).sign
BigRat(3, 1).exponent
BigRat(3, 1).significand


BigRat(-1, 3).sign
BigRat(-1, 3).exponent
BigRat(-1, 3).significand

IntRat(-1, 3).sign
IntRat(-1, 3).exponent
IntRat(-1, 3).significand

import Foundation
let encoder = JSONEncoder()
String(data:try encoder.encode(qpi), encoding:.utf8)
String(data:try encoder.encode(IntRat(1).over(3)), encoding:.utf8)
String(data:try encoder.encode([Int.max]), encoding:.utf8)

//: [Next](@next)
