//
//  bigint.swift
//  bignum
//
//  Created by Dan Kogai on 2/2/16.
//  Copyright © 2016 Dan Kogai. All rights reserved.
//

public struct BigUInt {
    var value = [UInt32]()
    public init(_ s:BigUInt) {
        self.value = s.value
    }
    public init(_ u:UInt32) {
        value.append(u)
    }
    public init(_ u:UInt16) { self.init(UInt32(u)) }
    public init(_ u:UInt8)  { self.init(UInt32(u)) }
    public init(_ u:UInt64) {
        value.append(UInt32(u & 0xFFFFffff))
        value.append(UInt32(u >> 32))
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
}