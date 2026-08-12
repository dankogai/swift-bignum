//
//  ComplexConformance.swift -- BigRat and BigFloat as swift-complex `RMath`s, so
//  that `Complex<BigRat>` and `Complex<BigFloat>` work.
//
//  Two empty extensions, and unlike SwiftNumericsExample they were empty from the
//  start.  swift-complex's `RMath` declares the elementary functions as
//  *requirements* and deliberately provides no defaults for the ones swift-bignum
//  already has, so there is nothing for BigNum's implementations to tie with:
//  each requirement has exactly one candidate, and it is BigNum's.
//
//  It also declares the `precision:debug:` forms as requirements rather than
//  conveniences, which is what lets generic code inside `Complex` dispatch to
//  arbitrary precision instead of binding a forwarder that drops the argument.
//  That is the whole difference between this file and the swift-numerics one.
//
//  Requires swift-complex's `main`.  Tag 5.0.0 spells the protocol
//  `FloatingPointMath`, with only `init(_:Double)` and `asDouble` as requirements
//  and every function supplied as an extension default routed through `Double`.
//  Conforming to that compiles, and then `Complex<BigRat>.exp(z)` returns exactly
//  what `Complex<Double>` returns -- 1.22e-16 from -1 for `exp(iπ)` rather than
//  1e-39 -- because generic code inside `Complex` can only see the Double-routed
//  default.  Silent, not an error.  It also makes about two dozen function names
//  ambiguous at any call site that imports both modules.
//
import BigNum
import Complex

extension BigRat: RMath {}
extension BigFloat: RMath {}
