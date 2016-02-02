import Cocoa    // This is an OSX playground
//: Playground - noun: a place where people can play

/*
func bfact(n:BigUInt)->BigUInt {
    // return n < 2 ? n : (2...n).reduce(1, combine:*)
    return n < 2 ? n : n * bfact(n - 1)
}

bfact(5)
bfact(100)

bfact(99) * 100 == bfact(100)

BigUInt.divmod32(0xffff_ffff_ffff_ffff, 0xff)
*/
BigUInt(UInt64.max)*BigUInt(UInt64.max)
var v = BigUInt("340282366920938463426481119284349108225")
v.debugDescription
BigUInt("fffffffffffffffe0000000000000001", base:16)
let (q,r) = BigUInt.divmod(v, 0xffff_ffff)
q
r
