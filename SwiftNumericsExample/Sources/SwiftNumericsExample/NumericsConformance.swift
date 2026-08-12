//
//  NumericsConformance.swift -- BigRat and BigFloat as swift-numerics `Real`s, so
//  that `Complex<BigRat>` and `Complex<BigFloat>` work.
//
//  Two empty extensions, which is the whole point.  Every method `RealModule.Real`
//  asks for is already on these types under the same name and signature -- BigNum's
//  own `Real` declares the same requirement set, deliberately, so that the library
//  needs no dependency.
//
//  It was not always two lines.  Four members -- `sqrt`, `exp10`, `reciprocal`,
//  `signGamma` -- have a default implementation in *both* hierarchies, and `/` did
//  too for `BigRat`.  Neither protocol refines the other, so nothing broke the tie,
//  and a requirement with two equally good witnesses is unsatisfied rather than
//  overloaded:
//
//      error: type 'BigFloat' does not conform to protocol 'AlgebraicField'
//      note: multiple matching properties named 'reciprocal' with type 'BigFloat?'
//
//  Those five used to be written out here, forwarding through a second file that
//  imported only BigNum -- because declaring `sqrt` on `BigFloat` makes it BigNum's
//  witness too, so the obvious body called itself.  BigNum now declares them on its
//  concrete types instead, where a member outranks any protocol-extension default,
//  and consumers get to write this:
//
import BigNum
import RealModule

extension BigRat: RealModule.Real {}
extension BigFloat: RealModule.Real {}
