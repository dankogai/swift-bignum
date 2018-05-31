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

import Foundation
let encoder = JSONEncoder()
String(data:try encoder.encode(qpi), encoding:.utf8)
String(data:try encoder.encode(IntRat(1).over(3)), encoding:.utf8)
String(data:try encoder.encode([Int.max]), encoding:.utf8)

//: [Next](@next)
