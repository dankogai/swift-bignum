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

///
/// has init(_:Self)
///
public protocol _SelfInitializable {
    init(_:Self)
}
///
/// strangely BitwiseOperationsType does not include these ops
///
public protocol _BitShiftable : IntegerArithmeticType, BitwiseOperationsType {
    func <<(_:Self,_:Self)->Self
    func <<=(inout _:Self, _:Self)
    func >>(_:Self,_:Self)->Self
    func >>=(inout _:Self, _:Self)
}
public protocol _Integer :  _SelfInitializable, _BitShiftable, IntegerType {}
/// Usage:
///
///     extension UInt: _UnsignedInteger {}     // already compliant
///     extension BigUInt: _UnsignedInteger {}  // ditto
///
public protocol _UnsignedInteger: UnsignedIntegerType, _Integer {}
/// Usage:
///
///     extension Int: _Integer {}      // already compliant
///     extension BigInt: _Integer {}   // ditto
///
public protocol _SignedInteger: SignedIntegerType, _Integer {}
