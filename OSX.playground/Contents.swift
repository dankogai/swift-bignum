import Cocoa    // This is an OSX playground
//: Playground - noun: a place where people can play

let bu:BigUInt = 0xffff_ffff_ffff
bu < BigUInt(UInt64.max)
var v = BigUInt()
v[127] = .One
v
v[127] = .Zero
v
v = 0xfedcba0123456789
v <<= 64
v |= 0xfedcba0123456789
v >>= 16
v = 0xffff_ffff
v += 1
v = 1
v = -v
v = 0x8000_0000_0000
v - 0x8000_0000_0000