import BigNum
import Darwin

//print(BigRat.pow(1.5, 1.5).asDouble)
//exit(0)
//let q = BigRat.log(2)
//print(q, q.toFloatingPointString())
//print(BigRat.log(1024, precision:128).toFloatingPointString())
//print(BigRat.normalizeAngle(BigRat.PI()*8))

//let sc = BigRat.sincos(1)
//print(sc)
//print(sc.cos.toFloatingPointString())
//print(sc.sin.toFloatingPointString())
//print(BigNum.constants)

//print(BigRat.atan(0.5))
print(BigRat.exp(2.0).asDouble)
print(BigRat.exp(-2.0).asDouble)
print(BigRat.exp(0.5).asDouble)
print(BigRat.exp(-0.5).asDouble)

exit(0)
// print(BigRat.log2(BigRat.exp(1)))
//print(q, BigRat.log(10))
print(BigNum.constants)
print(BigRat.exp(1))
print(BigRat.exp(2))
print(BigRat.exp(-1))

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
print(BigRat(+1).toFloatingPointString())
print(BigRat(-1).toFloatingPointString())
print((+bqpi).toFloatingPointString())
print((-bqpi).toFloatingPointString())
print((+BigRat.log(2)))
print((+BigRat.log(2)).toFloatingPointString())
print((+BigRat.log(2)).toFloatingPointString())
print(1.over(Int.max).toFloatingPointString())
print(BigRat(1.0/Double(Int.max)).toFloatingPointString())
({
    var d = 0.5
    var x = 1.0
    for i in (0...53) {
        print( "\(i):", BigRat(x).toFloatingPointString(), Double(x))
        d *= 0.5; x -= d
    }
})()
print(Int.max.over(-1).toFloatingPointString())
