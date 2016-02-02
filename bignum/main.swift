//
//  main.swift
//  bignum
//
//  Created by Dan Kogai on 2/2/16.
//  Copyright © 2016 Dan Kogai. All rights reserved.
//

let test = TAP()
test.eq(sizeof(BigUInt), sizeof(Array<UInt32>), "sizeof(BigUInt) == sizeof([UInt32])")

var v:BigUInt = 0xfedcba0123456789
v = (v << 64) | v
debugPrint(v)
v >>= 64
debugPrint(v)
v = 0xffff_ffff_ffff_ffff
v = (v << 64) | v
debugPrint(v)
v += 1
debugPrint(v)
/*
for i in 0...128 {
    debugPrint(v >> BigUInt(i))
}
*/
test.done()
