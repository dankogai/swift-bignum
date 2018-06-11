import BigNum
#if os(Linux)
import Glibc
#else
import Darwin
#endif

var dummy:Any = 0
for i in 0..<512 {
    // dummy = BigRat.log(BigRat(i))
    dummy = Float80.exp(Float80(i))
    // dummy = Double.log(Double(i))
}
print(dummy)
print(Double.exp(511))
