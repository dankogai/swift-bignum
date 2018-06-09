import BigNum
#if os(Linux)
import Glibc
#else
import Darwin
#endif

var (x, y) = (BigRat(0), BigRat(0))
for i in (0...1000) {
    x = BigRat.log2(BigRat(i), precision:128)
    y = BigRat.binaryLog(BigRat(i), precision:128)
}
exit(0)
//for i in (2...10) {
//    print(BigNum.bernoulliNumber(i) / BigRat(i * (i-1)))
//}
//print(BigRat.lgamma(-0x1.ffffffffffffp-52, precision:64).asDouble)
//print("BigRat.lgamma:", BigRat.lgamma(0.195).asDouble)
//print("Double.lgamma:", Double.lgamma(0.195))
//print("BigRat.lgamma:", BigRat.lgamma(-0.195).asDouble)
//print("Double.lgamma:", Double.lgamma(-0.195))
//exit(0)
//for i in (0...29) {
//    print(i, BigNum.bernoulliNumber(i))
//    print(i, BigNum.factorial(i))
//}

//for n in (0...10) {
//    for k in (0...n) {
//        print(BigNum.binominalCoefficient(BigInt(n), BigInt(k)), terminator:" ")
//    }
//    print()
//}

print(BigRat.atan(BigRat.PI()))
print(BigRat(1000).nthroot(3).asDouble)
print(BigRat(10000).nthroot(4).asDouble)
#if false
print(BigRat.tanh(BigRat(1.0/Double.greatestFiniteMagnitude)))
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
#endif
