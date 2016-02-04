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
///
/// Generic Integer, signed or unsigned.
///
public protocol _Integer :  _SelfInitializable, _BitShiftable, IntegerType {}
///
/// Generic unsigned integer.  All built-ins already conform to this.
///
public protocol _UnsignedInteger: UnsignedIntegerType, _Integer {}
extension UInt64:   _UnsignedInteger {}
extension UInt32:   _UnsignedInteger {}
extension UInt16:   _UnsignedInteger {}
extension UInt8:    _UnsignedInteger {}
extension UInt:     _UnsignedInteger {}
///
/// Generic signed integer.  All built-ins already conform to this.
///
public protocol _SignedInteger: SignedIntegerType, _Integer {}
extension Int64:    _SignedInteger {}
extension Int32:    _SignedInteger {}
extension Int16:    _SignedInteger {}
extension Int8:     _SignedInteger {}
extension Int:      _SignedInteger {}
