//
//  main.swift
//  bignum
//
//  Created by Dan Kogai on 2/2/16.
//  Copyright © 2016 Dan Kogai. All rights reserved.
//

let test = TAP()
test.eq(sizeof(BigUInt), sizeof(Array<UInt32>), "sizeof(BigUInt) == sizeof([UInt32])")
// protocol check
protocol UnsignedInteger: IntegerArithmeticType, UnsignedIntegerType {
    init(_:Self)
}
extension UInt: UnsignedInteger {}
extension BigUInt: UnsignedInteger {}
func fact<U:UnsignedInteger>(n:U)->U {
    return n < 2 ? n : (2...n).reduce(1, combine:*)
}
let fact20 = 2432902008176640000 as UInt
let fact42 = BigUInt("3C1581D491B28F523C23ABDF35B689C908000000000", base:16)
test.eq(fact(20 as UInt),       fact20, "20! as UInt    == \(fact20)")
test.eq(fact(42 as BigUInt),    fact42, "42! as BigUInt == \(fact42)")
test.done()
