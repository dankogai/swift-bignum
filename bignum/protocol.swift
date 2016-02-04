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
/// For the sake of protocol-oriented programming, 
/// consider extend this protocol first before extending each integer type.
///
public protocol GenericInteger :  _SelfInitializable, _BitShiftable, IntegerType {}
///
/// Generic unsigned integer.  All built-ins already conform to this.
///
/// For the sake of protocol-oriented programming,
/// consider extend this protocol first before extending each unsigned integer type.
///
public protocol GenericUInt: UnsignedIntegerType, GenericInteger {}
extension UInt64:   GenericUInt {}
extension UInt32:   GenericUInt {}
extension UInt16:   GenericUInt {}
extension UInt8:    GenericUInt {}
extension UInt:     GenericUInt {}
///
/// Generic signed integer.  All built-ins already conform to this.
///
/// For the sake of protocol-oriented programming,
/// consider extend this protocol first before extending each signed integer types.
///
public protocol GenericInt: SignedIntegerType, GenericInteger {}
extension Int64:    GenericInt {}
extension Int32:    GenericInt {}
extension Int16:    GenericInt {}
extension Int8:     GenericInt {}
extension Int:      GenericInt {}
