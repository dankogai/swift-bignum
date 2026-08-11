//
//  A one-line shim, and an unavoidable one.
//
//  attaswift's module is named `BigInt` and so is its main type, and swift-bignum
//  contains a class named `BigNum` -- so in a file importing both, neither
//  `BigInt.BigInt` nor `BigNum.BigInt` resolves: the first is ambiguous and the
//  second finds the class.  SwiftPM's `moduleAliases` looked like the answer and
//  is not (it renames the module but still insists on the original spelling at
//  the import).
//
//  Inside *this* module only attaswift is imported, so its `BigInt` is simply
//  what `BigInt` means -- no qualifying needed, which is the whole trick.  (Not
//  even `BigInt.BigInt` works here: the type shadows the module.)
//
//  This is the same collision that made swift-bignum re-export attaswift's BigInt
//  with `@_exported import` back when it was a dependency -- the thing the
//  README calls an undocumented acrobat.  Two libraries cannot both own the name
//  `BigInt` in one file, and only a benchmark ever wants them to.
//
import BigInt

public typealias AttaswiftBigInt = BigInt
public typealias AttaswiftBigUInt = BigUInt
