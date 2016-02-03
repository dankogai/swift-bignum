//
//  protocol.swift
//  bignum
//
//  Created by Dan Kogai on 2/3/16.
//  Copyright © 2016 Dan Kogai. All rights reserved.
//

/**:

very unfortunately protocol cannot be namespaced like:

    class C {
        protocol P
    }

so we resort to the _P notation (like Swift standard library

when you use them, you can typealias them

*/

/// Usage:
///
///     extension UInt: _UnsignedInteger {}
///     extension BigUInt: _UnsignedInteger {}
///
public protocol _UnsignedInteger: IntegerArithmeticType, UnsignedIntegerType {
    init(_:Self)
}
/// Usage:
///
///     extension Int: _Integer {}
///     extension BigInt: _Integer {}
///
public protocol _Integer: IntegerArithmeticType, SignedIntegerType {
    init(_:Self)
}
