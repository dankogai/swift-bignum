import BigNum

let bi = BigInt(1) << 128 - 1
let bq = BigInt(1).over(bi)
print(bi)
print(bq)

let bqpi = BigRat(Double.pi)
var d = Double.pi
d.formRemainder(dividingBy: 0.125)
print(bqpi % BigRat(0.125))
print(BigRat(d))

import Foundation
let jd = try JSONEncoder().encode(bq)
let js = String(data:jd, encoding:.utf8)!
print(js)
