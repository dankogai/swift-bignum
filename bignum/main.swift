//
//  main.swift
//  bignum
//
//  Created by Dan Kogai on 2/2/16.
//  Copyright © 2016 Dan Kogai. All rights reserved.
//

let test = TAP()
test.eq(sizeof(BigUInt), sizeof(Array<UInt32>), "sizeof(BigUInt) == sizeof([UInt32])")


func bfact(n:BigUInt)->BigUInt {
    // return n < 2 ? n : (2...n).reduce(1, combine:*)
    return n < 2 ? n : (2...n).reduce(1, combine:*)
}

var v = BigUInt("ffff_FFFF_ffff_FFFF_ffff_FFFF_ffff_FFFF"  ,base:16)
print(v / BigUInt("FFFF_ffff_FFFF",base:16))

// for i in 0 ... 127 {
//    print((BigUInt(1)<<BigUInt(i)).toString(16))
//}

test.done()
