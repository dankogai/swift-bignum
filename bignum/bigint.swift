//
//  bigint.swift
//  bignum
//
//  Created by Dan Kogai on 2/2/16.
//  Copyright © 2016 Dan Kogai. All rights reserved.
//

/// Big Unsigned Integer
public struct BigUInt {
    public typealias DigitType = UInt32
    var value = [DigitType]()
    public init(_ s:BigUInt) {
        self.value = s.value
    }
    // init from built-in types
    public init(_ u:UInt32) {
        value.append(u)
    }
    public init(_ u:UInt16) { self.init(UInt32(u)) }
    public init(_ u:UInt8)  { self.init(UInt32(u)) }
    public init(_ u:UInt64) {
        value.append(UInt32(u & 0xFFFFffff))
        if u > UInt64(UInt32.max) { // append higer half only if necessary
            value.append(UInt32(u >> 32))
        }
    }
    public init(_ u:UInt) { self.init(u.toUIntMax()) }
    public init() {
        self.init(UInt32(0))
    }
    public init(_  i:Int8)  { self.init(UInt8(i))  }
    public init(_  i:Int16) { self.init(UInt16(i)) }
    public init(_  i:Int32) { self.init(UInt32(i)) }
    public init(_  i:Int64) { self.init(UInt64(i)) }
    public init(_  i:Int)   { self.init(UInt(i))   }
    public init(_ d:Double) { self.init(Int(d)) }
    public init(_ f:Float)  { self.init(Int(f)) }
    // conversions
    public var asUInt32:UInt32 {
        if value.count != 1 { fatalError("value too large for UInt32") }
        return value[0]
    }
    public var asUInt16:UInt16 { return UInt16(self.asUInt32) }
    public var asUInt8:UInt8    { return UInt8(self.asUInt32) }
    public var asUInt64:UInt64 {
        return UInt64(
            value.count == 2 ? (value[1] << 32 | value[0]) : value[0]
        )
    }
    public var asInt:Int        { return Int(self.asUInt64) }
    public var asUInt:UInt      { return UInt(self.asUInt64) }
    public var asDouble:Double  { return Double(self.asUInt64) }
    public var asFloat:Float    { return Float(self.asUInt64) }
}
// reverse conversions
public extension Int    { public init(_ bu:BigUInt){ self.init(bu.asInt) } }
public extension UInt   { public init(_ bu:BigUInt){ self.init(bu.asUInt) } }
public extension Double { public init(_ bu:BigUInt){ self.init(bu.asDouble) } }
public extension Float  { public init(_ bu:BigUInt){ self.init(bu.asFloat) } }
// 0th protocol to conform : IntegerLiteralConvertible
extension BigUInt: IntegerLiteralConvertible, _BuiltinIntegerLiteralConvertible {
    public typealias IntegerLiteralType = UInt64.IntegerLiteralType
    public init(integerLiteral:IntegerLiteralType) {
        self.init(integerLiteral.toUIntMax())
    }
    public init(_builtinIntegerLiteral:_MaxBuiltinIntegerType) {
        self.init(UInt64(_builtinIntegerLiteral: _builtinIntegerLiteral))
    }
}
// of course BigUInt is Equatable
extension BigUInt: Equatable {}
public func == (lhs:BigUInt, rhs:BigUInt)->Bool {
    return lhs.value == rhs.value
}
// and Comparable
extension BigUInt: Comparable {}
public func < (lhs:BigUInt, rhs:BigUInt)->Bool {
    if lhs.value.count > rhs.value.count { return false }
    if lhs.value.count < rhs.value.count { return true }
    for i in (0..<lhs.value.count).reverse() {
        if lhs.value[i] > rhs.value[i] { return false }
        if lhs.value[i] < rhs.value[i] { return true }
    }
    return false
}
// BigUInt as [Bit]
extension BigUInt : BitwiseOperationsType {
    public static let allZeros = BigUInt(0)
    public static let bitsPerDigit = 32
    /// stretch the internal array so it can accept d * 32 bits
    /// parameter d: number of digits
    public mutating func stretch(d:Int) {
        if value.count <= d {   // stretch if necessary
            for _ in value.count...d { value.append(0) }
        }
    }
    /// trim uncessary upper digits
    public mutating func trim() {
        while value.count > 1 {
            if value[value.count - 1] != 0 { return }
            value.removeLast()
        }
    }
    /// init from raw value -- always trimmed
    public init(rawValue:[UInt32]) {
        self.value = rawValue
        self.trim()
    }
    public subscript(i:Int)->Bit {
        get {
            let (digit, offset) = (i / 32, i % 32)
            if value.count <= digit { return .Zero }
            return value[digit] & UInt32(1 << offset) == 0 ? .Zero : .One
        }
        set {
            let (digit, offset) = (i / 32, i % 32)
            if newValue == .One {
                self.stretch(digit)
                value[digit] |= UInt32(1 << offset)
            } else {
                if digit < value.count {    // set iff value exists
                    value[digit] &= ~UInt32(1 << offset)
                    self.trim()
                }
            }
        }
    }
    public static func binop(op:(DigitType,DigitType)->DigitType)
        ->(BigUInt,BigUInt)->BigUInt {
        return { lhs, rhs in
            let (l, r) = lhs.value.count < rhs.value.count ? (rhs, lhs) : (lhs, rhs)
            var value = l.value
            for i in 0..<r.value.count {
                value[i] = op(value[i], r.value[i])
            }
            return BigUInt(rawValue:value)
        }
    }
    public static let bitAnd = BigUInt.binop(&)
    public static let bitOr  = BigUInt.binop(|)
    public static let bitXor = BigUInt.binop(^)
    public static func bitNot(bs:BigUInt)->BigUInt {
        return BigUInt(rawValue: bs.value.map{ ~$0 } )
    }
    public static func bitShiftL(lhs:BigUInt, _ rhs:DigitType)->BigUInt {
        if lhs == 0 { return lhs }
        let (digit, offset) = (rhs / 32, rhs % 32)
        let blank = [DigitType](count:Int(digit), repeatedValue:0)
        if offset == 0 { return BigUInt(rawValue: blank + lhs.value) }
        let shift = lhs.value.map{ $0 << DigitType(offset) } + [0]
        let carry = [0] + lhs.value.map{ $0 >> DigitType(32 - offset) }
        let value = zip(shift, carry).map { $0.0 | $0.1 }
        return BigUInt(rawValue:blank + value)
    }
    public static func bitShiftL(lhs:BigUInt, _ rhs:BigUInt)->BigUInt {
        return bitShiftL(lhs, rhs.asUInt32)
    }
    public static func bitShiftR(lhs:BigUInt, _ rhs:DigitType)->BigUInt {
        if lhs == 0 { return lhs }
        var value = lhs.value
        let (digit, offset) = (rhs / 32, rhs % 32)
        if value.count <= Int(digit) {
            return 0
        }
        value.removeFirst(Int(digit))
        if offset == 0 { return BigUInt(rawValue:value) }
        let e = 0
        let b = value.count
        let ol = offset
        let oh = 32 - ol
        let mask = ~0 >> oh
        value.append(0) // add sentinel
        for i in e..<b {
            value[i] = ((value[i+1] & mask) << oh) | (value[i] >> ol)
        }
        return BigUInt(rawValue:value)
    }
    public static func bitShiftR(lhs:BigUInt, _ rhs:BigUInt)->BigUInt {
        return bitShiftR(lhs, rhs.asUInt32)
    }
}
// Bitwise ops
public prefix func ~(bs:BigUInt)->BigUInt {
    return BigUInt.bitNot(bs)
}
public func &(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.bitAnd(lhs, rhs)
}
public func &=(inout lhs:BigUInt, rhs:BigUInt) {
    lhs = lhs & rhs
}
public func |(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.bitOr(lhs, rhs)
}
public func |=(inout lhs:BigUInt, rhs:BigUInt) {
    lhs = lhs | rhs
}
public func ^(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.bitXor(lhs, rhs)
}
public func ^=(inout lhs:BigUInt, rhs:BigUInt) {
    lhs = lhs ^ rhs
}
public func <<(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.bitShiftL(lhs, rhs)
}
public func <<=(inout lhs:BigUInt, rhs:BigUInt) {
    lhs = lhs << rhs
}
public func >>(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.bitShiftR(lhs, rhs)
}
public func >>=(inout lhs:BigUInt, rhs:BigUInt) {
    lhs = lhs >> rhs
}
// addtition and subtraction
public extension BigUInt {
    public static func add(lhs:BigUInt, _ rhs:BigUInt)->BigUInt {
        let (l, r) = lhs.value.count < rhs.value.count ? (rhs, lhs) : (lhs, rhs)
        var value = l.value
        value.append(0) // sentinel
        var carry:UInt64 = 0
        for i in 0..<r.value.count {
            carry = UInt64(value[i]) + UInt64(r.value[i]) + (carry >> 32)
            value[i] = DigitType(carry & 0xffff_ffff)
        }
        for i in r.value.count..<value.count {
            carry = UInt64(value[i]) + (carry >> 32)
            value[i] = DigitType(carry & 0xffff_ffff)
            if carry <= 0xffff_ffff { break }
        }
        return BigUInt(rawValue:value)
    }
    /// addition never overflows
    public static func addWithOverflow(lhs:BigUInt, _ rhs:BigUInt)->(BigUInt, overflow:Bool) {
        return (add(lhs, rhs), overflow:false)
    }
    /// subtraction overflows when lhs < rhs
    public static func subtractWithOverflow(lhs:BigUInt, _ rhs:BigUInt)->(BigUInt, overflow:Bool) {
        if rhs == 0 { return (lhs, false) }
        var s = rhs
        s.stretch(lhs.value.count-1)
        let count = s.value.count
        s = bitNot(s)
        s += 1
        s += lhs
        if s.value.count > count { s.value.removeLast() } // remove carry
        s.trim()    // it can be zero
        return (s, overflow: lhs < rhs)
   }
    public static func subtract(lhs:BigUInt, _ rhs:BigUInt)->BigUInt {
        let result = subtractWithOverflow(lhs, rhs)
        if result.overflow {
            fatalError("arithmetic operation '\(lhs) - \(rhs)' (on type 'BigUInt') results in an overflow")
        }
        return result.0
    }
}
public func +(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.add(lhs, rhs)
}
public func &+(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.addWithOverflow(lhs, rhs).0
}
public prefix func +(bs:BigUInt)->BigUInt {
    return bs
}
public func +=(inout lhs:BigUInt, rhs:BigUInt) {
    lhs = lhs + rhs
}
public func -(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.subtract(lhs, rhs)
}
public func &-(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.subtractWithOverflow(lhs, rhs).0
}
public prefix func -(bs:BigUInt)->BigUInt {
    return 0 - bs
}
public func -=(inout lhs:BigUInt, rhs:BigUInt) {
    lhs = lhs - rhs
}
// multiplication
public extension BigUInt {
    public static func multiply32(lhs:BigUInt, _ rhs:DigitType)->BigUInt {
        var value = lhs.value
        value.append(0) // sentinel
        var carry:UInt64 = 0
        for i in 0..<lhs.value.count {
            carry = UInt64(value[i]) * UInt64(rhs) + (carry >> 32)
            value[i] = DigitType(carry & 0xffff_ffff)
        }
        value[lhs.value.count] = DigitType(carry >> 32)
        return BigUInt(rawValue:value)
    }
    public static func multiply(lhs:BigUInt, _ rhs:BigUInt)->BigUInt {
        var result = BigUInt()
        for i in 0..<rhs.value.count {
            result += bitShiftL(multiply32(lhs, rhs.value[i]), DigitType(i * 32))
        }
        return result
    }
    /// multiplication never overflows
    public static func multiplyWithOverflow(lhs:BigUInt, _ rhs:BigUInt)->(BigUInt, overflow:Bool) {
        return (multiply(lhs, rhs), overflow:false)
    }
}
public func *(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.multiply(lhs, rhs)
}
public func &*(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.multiplyWithOverflow(lhs, rhs).0
}
public func *=(inout lhs:BigUInt, rhs:BigUInt) {
    lhs = lhs * rhs
}
// before we get down to division, let's define divmod32 
// and use it to make it conform to CustomStringConvertible
// (and CustomDebugStringConvertible and  Hashable)
extension BigUInt : CustomStringConvertible, CustomDebugStringConvertible, Hashable {
    public static func divmod32(lhs:BigUInt, _ rhs:DigitType)->(BigUInt, DigitType) {
        var value = lhs.value
        // value.append(0) // sentinel
        var carry:UInt64 = 0
        for i in (0..<lhs.value.count).reverse() {
            carry = UInt64(carry % UInt64(rhs)) << 32 + UInt64(value[i])
            value[i] = UInt32(carry / UInt64(rhs))
        }
        return (BigUInt(rawValue:value), UInt32(carry % UInt64(rhs)))
    }
    public static let int2char = Array("0123456789abcdefghijklmnopqrstuvwxyz".characters)
    public func toString(base:Int = 10)-> String {
        guard 2 <= base && base <= 36 else {
            fatalError("base out of range. \(base) is not within 2...36")
        }
        var bu = self
        var digits = [Int]()
        repeat {
            var r:UInt32
            (bu, r) = BigUInt.divmod32(bu, UInt32(base))
            digits.append(Int(r))
        } while bu != 0
        return digits.reverse().map{"\(BigUInt.int2char[$0])"}.joinWithSeparator("")
    }
    public var description:String {
        return self.toString()
    }
    public var debugDescription:String {
        return "BigUInt(\"" + self.toString(16) + "\", base:16)"
    }
    public static let char2int:[Character:Int] = {
        var result = [Character:Int]()
        for i in 0..<int2char.count {
            result[int2char[i]] = i
        }
        return result
    }()
    /// init from string
    public init(_ s:String, base:Int = 10) {
        self.init(0)
        for c in s.lowercaseString.characters {
            if let d = BigUInt.char2int[c] {
                self = BigUInt.multiply32(self, UInt32(base))
                self += BigUInt(d)
            }
        }
    }
    public var hashValue : Int {    // slow but steady
        return self.description.hashValue
    }
}
// now let's go for the toughest one:division!
public extension BigUInt {
    public var msbAt:Int {
        return self.value.count * 32 + Double.frexp(Double(self.value.last!)).1 - 1
    }
    public static func divmod(lhs:BigUInt, _ rhs:BigUInt)->(BigUInt, BigUInt) {
        if rhs <= BigUInt(UInt32.max) {
            let (q, r) = divmod32(lhs, rhs.asUInt32)
            return (q, BigUInt(r))
        }
        // slow but steady division algorithm
        var q = BigUInt(0)
        var r = BigUInt(0)
        for i in (0...lhs.msbAt).reverse() {
            r <<= 1
            //print("i:  \(i)\n  R:  \(r)")

            r[0] = lhs[i]
            // print("i:  \(i)\n  r:  \(r)\n  rhs:\(rhs)\n  q:  \(q)")
            if r >= rhs {
                r -= rhs
                q[i] = .One
            }
        }
        return (q, r)
    }
    // no overflow
    public static func divideWithOverflow(lhs:BigUInt, _ rhs:BigUInt)->(BigUInt, overflow:Bool) {
        return (divmod(lhs, rhs).0, false)
    }
    // no overflow
    public static func remainderWithOverflow(lhs:BigUInt, _ rhs:BigUInt)->(BigUInt, overflow:Bool) {
        return (divmod(lhs, rhs).1, false)
    }

}
public func /(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.divmod(lhs, rhs).0
}
public func %(lhs:BigUInt, rhs:BigUInt)->BigUInt {
    return BigUInt.divmod(lhs, rhs).1
}
// we are pretty much done.  Let's conform to remaining protocols.
//
// // makes Range<BigUInt> possible
extension BigUInt : RandomAccessIndexType {
    public typealias Distance = Int.Distance
    public func successor() -> BigUInt {
        return self + 1
    }
    public func predecessor() -> BigUInt {
        return self - 1
    }
    public typealias Stride = Distance
    public func advancedBy(n: Stride) -> BigUInt {
        return self + BigUInt(n)
    }
    public func distanceTo(end: BigUInt) -> Stride {
        return Distance(self) - Distance(end)
    }
}
// and BigUInt is
extension BigUInt : UnsignedIntegerType {
    public func toIntMax()->IntMax {
        return IntMax(self.asInt)
    }
    public func toUIntMax()->UIntMax {
        return UIntMax(self.asUInt)
    }
}


