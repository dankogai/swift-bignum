//
//  bigint.swift
//  bignum
//
//  Created by Dan Kogai on 2/2/16.
//  Copyright © 2016 Dan Kogai. All rights reserved.
//

/// Big Signed Integer
public struct BigInt {
    public var unsignedValue = BigUInt()
    public var isSignMinus = false
    public init(){}
    public init(_ bi:BigInt) {
        self.unsignedValue = bi.unsignedValue
    }
    public init(unsignedValue:BigUInt, isSignMinus:Bool=false) {
        self.unsignedValue = unsignedValue
        self.isSignMinus = isSignMinus
    }
    public init(_ bu:BigUInt) {
        self.init(unsignedValue: bu)
    }
    // init from built-in unsigned integers
    public init(_ u:UInt64) { unsignedValue = BigUInt(u) }
    public init(_ u:UInt32) { unsignedValue = BigUInt(u) }
    public init(_ u:UInt16) { unsignedValue = BigUInt(u) }
    public init(_ u:UInt8)  { unsignedValue = BigUInt(u) }
    public init(_ u:UInt)   { unsignedValue = BigUInt(u) }
}
// 0th protocol to conform : IntegerLiteralConvertible
extension BigInt: IntegerLiteralConvertible, _BuiltinIntegerLiteralConvertible {
    public typealias IntegerLiteralType = Int64.IntegerLiteralType
    public init(integerLiteral:IntegerLiteralType) {
        self.init(integerLiteral.toIntMax())
    }
    public init(_builtinIntegerLiteral:_MaxBuiltinIntegerType) {
        self.init(UInt64(_builtinIntegerLiteral: _builtinIntegerLiteral))
    }
}
extension BigInt: Equatable {}
public func ==(lhs:BigInt, rhs:BigInt)->Bool {
    return lhs.isSignMinus == rhs.isSignMinus && lhs.unsignedValue == rhs.unsignedValue
}
extension BigInt: Comparable {}
public func <(lhs:BigInt, rhs:BigInt)->Bool {
    if lhs.isSignMinus == rhs.isSignMinus {
        return lhs.isSignMinus
            ? lhs.unsignedValue > rhs.unsignedValue
            : lhs.unsignedValue < rhs.unsignedValue
    }
    return lhs.isSignMinus ? true : false
}
// 0th operators :  - and +, prefix and infix
public prefix func -(bi:BigInt)->BigInt {
    return BigInt(unsignedValue:bi.unsignedValue, isSignMinus:!bi.isSignMinus)
}
public prefix func +(bi:BigInt)->BigInt {
    return bi
}
public func +(lhs:BigInt, rhs:BigInt)->BigInt {
    if lhs.isSignMinus != rhs.isSignMinus {
        let unsignedValue = lhs.unsignedValue < rhs.unsignedValue
            ?   rhs.unsignedValue - lhs.unsignedValue
            :   lhs.unsignedValue - rhs.unsignedValue
        return BigInt(
            unsignedValue: unsignedValue,
            isSignMinus: BigInt.xor(lhs.unsignedValue < rhs.unsignedValue, lhs.isSignMinus)
        )
    }
    return BigInt(unsignedValue: lhs.unsignedValue + rhs.unsignedValue, isSignMinus: lhs.isSignMinus)
}
public func -(lhs:BigInt, rhs:BigInt)->BigInt {
    return lhs + (-rhs)
}
extension BigInt : AbsoluteValuable, SignedNumberType {
    public var abs:BigInt {
        return self.isSignMinus ? -self : +self
    }
    public static func abs(bi:BigInt)->BigInt {
        return bi.abs
    }
    public init(_  i:Int64) {
        self = BigInt(unsignedValue:BigUInt(Swift.abs(i as Int64)), isSignMinus:i < 0)
    }
    public init(_  i:Int32) {
        self = BigInt(unsignedValue:BigUInt(Swift.abs(i as Int32)), isSignMinus:i < 0)
    }
    public init(_  i:Int16) { self.init(Int32(i)) }
    public init(_  i:Int8)  { self.init(Int32(i)) }
    public init(_  i:Int)   { self.init(Int64(i)) }
    public init(_ d:Double) { self.init(Int(d))   }
    public init(_ f:Float)  { self.init(Int(f))   }
}
//
public func abs(bi:BigInt)->BigInt { return bi.abs }
//
extension BigInt : CustomStringConvertible, CustomDebugStringConvertible, StringLiteralConvertible {
    public func toString(base:Int = 10)-> String {
        return (self.isSignMinus ? "-" : "") + unsignedValue.toString(base)
    }
    public var description:String {
        return self.toString()
    }
    public var debugDescription:String {
        return (self.isSignMinus ? "-" : "") + self.unsignedValue.debugDescription
    }
    public init(_ s:String, base:Int = 10) {
        self.init(0)
        if s[s.startIndex] == "-" || s[s.startIndex] == "+" {
            unsignedValue = BigUInt(s[s.startIndex.successor()..<s.endIndex], base:base)
        } else {
            unsignedValue = BigUInt(s, base:base)
        }
        isSignMinus =  s[s.startIndex] == "-"
    }
    public typealias StringLiteralType = String
    public init(stringLiteral: StringLiteralType) {
        self.init(stringLiteral)
    }
    public typealias UnicodeScalarLiteralType = String
    public init(unicodeScalarLiteral: UnicodeScalarLiteralType) {
        self.init(stringLiteral: "\(unicodeScalarLiteral)")
    }
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    public init(extendedGraphemeClusterLiteral: ExtendedGraphemeClusterLiteralType) {
        self.init(stringLiteral: extendedGraphemeClusterLiteral)
    }
}
extension BigInt: Hashable {
    public var hashValue : Int {    // slow but steady
        return self.debugDescription.hashValue
    }
}
extension BigInt : RandomAccessIndexType {
    public typealias Distance = Int.Distance
    public func successor() -> BigInt {
        return self + 1
    }
    public func predecessor() -> BigInt {
        return self - 1
    }
    public typealias Stride = Distance
    public func advancedBy(n: Stride) -> BigInt {
        return self + BigInt(n)
    }
    public func distanceTo(end: BigInt) -> Stride {
        return self.asInt - Distance(end)
    }
}
extension BigInt : BitwiseOperationsType {
    public static let allZeros = BigInt(0)
}
// Bitwise ops
public prefix func ~(bs:BigInt)->BigInt {
    return BigInt(unsignedValue: ~bs.unsignedValue)
}
public func &(lhs:BigInt, rhs:BigInt)->BigInt {
    return BigInt(unsignedValue:lhs.unsignedValue & rhs.unsignedValue)
}
public func &=(inout lhs:BigInt, rhs:BigInt) {
    lhs = lhs & rhs
}
public func |(lhs:BigInt, rhs:BigInt)->BigInt {
    return BigInt(unsignedValue:lhs.unsignedValue | rhs.unsignedValue)
}
public func |=(inout lhs:BigInt, rhs:BigInt) {
    lhs = lhs | rhs
}
public func ^(lhs:BigInt, rhs:BigInt)->BigInt {
    return BigInt(unsignedValue:lhs.unsignedValue ^ rhs.unsignedValue)
}
public func ^=(inout lhs:BigInt, rhs:BigInt) {
    lhs = lhs ^ rhs
}
public func <<(lhs:BigInt, rhs:BigInt)->BigInt {
    return BigInt(
        unsignedValue:lhs.unsignedValue << rhs.unsignedValue,
        isSignMinus: lhs.isSignMinus
    )
}
public func <<=(inout lhs:BigInt, rhs:BigInt) {
    lhs = lhs << rhs
}
public func >>(lhs:BigInt, rhs:BigInt)->BigInt {
    return BigInt(
        unsignedValue:lhs.unsignedValue >> rhs.unsignedValue,
        isSignMinus: lhs.isSignMinus
    )
}
public func >>=(inout lhs:BigInt, rhs:BigInt) {
    lhs = lhs >> rhs
}
extension BigInt : SignedIntegerType {
    /// logical XOR
    ///
    /// handy to determine the sign of * and /
    public static func xor(lhs:Bool, _ rhs:Bool)->Bool {
        return lhs ? rhs ? false : true : rhs ? true : false
    }
    // no overflow for BigInt, period.
    public static func addWithOverflow(lhs:BigInt, _ rhs:BigInt)->(BigInt, overflow:Bool) {
        return (lhs + rhs, false)
    }
    public static func subtractWithOverflow(lhs:BigInt, _ rhs:BigInt)->(BigInt, overflow:Bool) {
        return (lhs - rhs, false)
    }
    public static func multiplyWithOverflow(lhs:BigInt, _ rhs:BigInt)->(BigInt, overflow:Bool) {
        return (lhs * rhs, false)
    }
    public static func divmod(lhs:BigInt, _ rhs:BigInt)->(BigInt, BigInt) {
        let (q, r) = BigUInt.divmod(lhs.unsignedValue, rhs.unsignedValue)
        return (
            BigInt(unsignedValue:q, isSignMinus: xor(lhs.isSignMinus, rhs.isSignMinus)),
            BigInt(unsignedValue:r, isSignMinus: lhs.isSignMinus)
        )
    }
    public static func divideWithOverflow(lhs:BigInt, _ rhs:BigInt)->(BigInt, overflow:Bool) {
        return (divmod(lhs, rhs).0, false)
    }
    public static func remainderWithOverflow(lhs:BigInt, _ rhs:BigInt)->(BigInt, overflow:Bool) {
        return (divmod(lhs, rhs).1, false)
    }
    // conversions
    public var asUInt64:UInt64 {
        if self.isSignMinus {
            fatalError("can't convert the negative number")
        }
        if self.abs > BigInt(UInt64.max) {
            fatalError("too large for UInt64")
        }
        return self.unsignedValue.asUInt64

    }
    public var asInt64:Int64 {
        if self.abs > BigInt(Int64.max) {
            fatalError("too large for Int64")
        }
        let a = (self.isSignMinus ? -self : +self).asUInt64.toIntMax()
        return self.isSignMinus ? -a : +a
    }
    public var asInt:Int        { return Int(self.asInt64) }
    public var asDouble:Double  { return Double(self.asInt64) }
    public var asFloat:Float    { return Float(self.asInt64) }

    public func toIntMax()->IntMax {
        return self.asInt.toIntMax()
    }
    public func toUIntMax()->UIntMax {
        return self.unsignedValue.toUIntMax()
    }
}
// and arithmetic operators
public func *(lhs:BigInt, rhs:BigInt)->BigInt {
    return BigInt(
        unsignedValue:  lhs.abs.unsignedValue * rhs.unsignedValue,
        isSignMinus:    BigInt.xor(lhs.isSignMinus, rhs.isSignMinus)
    )
}
public func &*(lhs:BigInt, rhs:BigInt)->BigInt {
    return lhs * rhs
}
public func *=(inout lhs:BigInt, rhs:BigInt) {
    lhs = lhs * rhs
}
public func /(lhs:BigInt, rhs:BigInt)->BigInt {
    return BigInt.divmod(lhs, rhs).0
}
public func %(lhs:BigInt, rhs:BigInt)->BigInt {
    return BigInt.divmod(lhs, rhs).1
}
// reverse conversions
public extension Int    { public init(_ bi:BigInt){ self.init(bi.toIntMax()) } }
public extension UInt   { public init(_ bi:BigInt){ self.init(bi.toUIntMax()) } }
public extension Double { public init(_ bi:BigInt){ self.init(bi.asDouble) } }
public extension Float  { public init(_ bi:BigInt){ self.init(bi.asFloat) } }
//
extension BigInt: GenericInt {}
