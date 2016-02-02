//
//  main.swift
//  bignum
//
//  Created by Dan Kogai on 2/2/16.
//  Copyright © 2016 Dan Kogai. All rights reserved.
//

let test = TAP()
test.eq(sizeof(BigUInt), sizeof(Array<UInt32>), "sizeof(BigUInt) == sizeof([UInt32])")
test.done()
