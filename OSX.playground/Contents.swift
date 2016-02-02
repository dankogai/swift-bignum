import Cocoa    // This is an OSX playground
//: Playground - noun: a place where people can play

func bfact(n:BigUInt)->BigUInt {
    // return n < 2 ? n : (2...n).reduce(1, combine:*)
    return n < 2 ? n : (2...n).reduce(1, combine:*)
}

/*
bfact(99) * 100 == bfact(100)
bfact(100) / 100 == bfact(99)
bfact(100) / bfact(99)

BigUInt(0x7fff_ffff_ffff_ffff) / 0xffff_ffff_ffff

BigUInt(0xffff_ffff_ffff) % 0xffff_ffff

BigUInt(1) << 33
*/

bfact(100)/bfact(99)

