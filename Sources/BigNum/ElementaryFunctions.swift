//
//  ElementaryFunctions.swift -- what the transcendental functions are, and what
//  they are at arbitrary precision.
//
//  The two protocols come first; `Real` inherits them and lives in Real.swift
//  with `AlgebraicField` and `Double`'s conformance.  Everything after them is
//  `BigFloatingPoint`'s implementation, in the `precision:`-taking form that is
//  the reason BigNum exists -- with the fixed-arity shims that satisfy the
//  protocol requirements (`exp(x)` forwarding to `exp(x, precision:
//  Self.precision)`, and so on) at the bottom of the file.
//

///
/// The transcendental functions that every real *and* complex type can offer.
///
public protocol ElementaryFunctions {
    /// e^x
    static func exp(_ x: Self) -> Self
    /// e^x - 1, accurate even for tiny `x`
    static func expMinusOne(_ x: Self) -> Self
    /// cosh(x)
    static func cosh(_ x: Self) -> Self
    /// sinh(x)
    static func sinh(_ x: Self) -> Self
    /// tanh(x)
    static func tanh(_ x: Self) -> Self
    /// cos(x)
    static func cos(_ x: Self) -> Self
    /// sin(x)
    static func sin(_ x: Self) -> Self
    /// tan(x)
    static func tan(_ x: Self) -> Self
    /// log(x)
    static func log(_ x: Self) -> Self
    /// log(1 + x), accurate even for tiny `x`
    static func log(onePlus x: Self) -> Self
    /// acosh(x)
    static func acosh(_ x: Self) -> Self
    /// asinh(x)
    static func asinh(_ x: Self) -> Self
    /// atanh(x)
    static func atanh(_ x: Self) -> Self
    /// acos(x)
    static func acos(_ x: Self) -> Self
    /// asin(x)
    static func asin(_ x: Self) -> Self
    /// atan(x)
    static func atan(_ x: Self) -> Self
    /// x^y
    static func pow(_ x: Self, _ y: Self) -> Self
    /// x^n
    static func pow(_ x: Self, _ n: Int) -> Self
    /// √x
    static func sqrt(_ x: Self) -> Self
    /// The `n`th root of `x`
    static func root(_ x: Self, _ n: Int) -> Self
}

///
/// The functions that only make sense for a *real* type.
///
public protocol RealFunctions : ElementaryFunctions {
    /// atan(y/x), resolved to the correct quadrant
    static func atan2(y: Self, x: Self) -> Self
    /// The error function
    static func erf(_ x: Self) -> Self
    /// 1 - erf(x), without the cancellation
    static func erfc(_ x: Self) -> Self
    /// 2^x
    static func exp2(_ x: Self) -> Self
    /// 10^x
    static func exp10(_ x: Self) -> Self
    /// √(x² + y²), without spurious overflow
    static func hypot(_ x: Self, _ y: Self) -> Self
    /// Γ(x)
    static func gamma(_ x: Self) -> Self
    /// log₂(x)
    static func log2(_ x: Self) -> Self
    /// log₁₀(x)
    static func log10(_ x: Self) -> Self
    /// log(|Γ(x)|) -- see `signGamma(_:)` for the sign it drops
    static func logGamma(_ x: Self) -> Self
    /// The sign `logGamma(_:)` discards
    static func signGamma(_ x: Self) -> FloatingPointSign
}

extension BigFloatingPoint {
    // MARK: - constants
    //
    // Each of these caches its result per precision in a `static var`, and each
    // access to that var happens inside `_memoLock` -- the read as well as the
    // write, since an unsynchronised read of a tuple holding a reference-counted
    // value is exactly as damaging as an unsynchronised write.  The read has to be
    // *lexically* inside the closure: passing the var to a helper, or by `inout`,
    // evaluates its getter before the lock is taken and protects nothing.
    //
    // The computation itself runs with no lock held.  That is deliberate -- see
    // Lock.swift -- because constants ask for other constants, and a lock spanning
    // the computation would deadlock on itself.  The cost is that two threads may
    // compute the same constant at once and one result is dropped, which wastes
    // work and cannot give a wrong answer.

    /// √2
    public static func SQRT2(precision px:Int=Self.precision, debug db:Bool=false)->Self {
        let apx = Swift.abs(px)
        let cached = _memoLock.withLock { SQRT2 }
        if apx <= cached.precision { return cached.value.truncated(width: apx) }
        // Truncated for the same reason LN10 is: `squareRoot(precision:)` returns a
        // little more than was asked for, and the cache-hit path above truncates,
        // so without this the first call at a precision disagrees with the rest.
        let v = Self(2).squareRoot(precision: apx).truncated(width: apx)
        _memoLock.withLock { if SQRT2.precision < apx { SQRT2 = (precision: apx, value: v) } }
        return v
    }
    /// euler's constant
    public static func E(precision px:Int=Self.precision, debug db:Bool=false)->Self {
        let apx = Swift.abs(px)
        let cached = _memoLock.withLock { E }
        if apx <= cached.precision { return cached.value.truncated(width: apx) }
        // `Self.self == BigRat.self` where this used to ask `E.value is BigRat`:
        // the same question, without reading the memo to answer it
        let v:Self = Self.self == BigRat.self ? {
            let epsilon = getEpsilon(precision: px)
            var (e, d) = (Self(1), Self(1))
            for i in 1 ... apx {
                d *= Self(i)
                let t = d.reciprocal!
                e += t
                if t < epsilon { break }
            }
            return e.truncated(width: apx)
        }() : Self(BigRat.E(precision: apx))
        _memoLock.withLock { if E.precision < apx { E = (precision: apx, value: v) } }
        return v
    }
    /// log(2)
    public static func LN2(precision px:Int=Self.precision, debug db:Bool = false)->Self {
        let apx = Swift.abs(px)
        let cached = _memoLock.withLock { LN2 }
        if apx <= cached.precision { return cached.value.truncated(width: apx) }
        let v:Self = Self.self == BigRat.self ? {
            let epsilon = getEpsilon(precision: px)
            var (t, r) = (Self(1)/Self(3), Self(1)/Self(3))
            for i in 1...px.magnitude {
                t *= Self(1)/Self(9)
                if db { print("\(Self.self).LN2: i=\(i), r=~\(r)") }
                if t < epsilon { break }
                r += t / Self(2 * i + 1)
            }
            return (2*r).truncated(width: apx)
        }() : Self(BigRat.LN2(precision: apx))
        _memoLock.withLock { if LN2.precision < apx { LN2 = (precision: apx, value: v) } }
        return v
    }
    /// log(10)
    public static func LN10(precision px:Int=Self.precision, debug db:Bool=false)->Self {
        let apx = Swift.abs(px)
        let cached = _memoLock.withLock { LN10 }
        if apx <= cached.precision { return cached.value.truncated(width: apx) }
        // Truncated like the other four.  Without this, `log` hands back more bits
        // than were asked for and LN10 returns them -- so the *first* call at a
        // precision gave a wider value than every call after it, which comes back
        // through the cache truncated.  Concurrency made that visible (the same
        // request answered differently depending on who got there first) but it
        // was never a race: it is one call disagreeing with the next.
        let v = Self.log(10, precision:apx).truncated(width: apx)
        _memoLock.withLock { if LN10.precision < apx { LN10 = (precision: apx, value: v) } }
        return v
    }
    /// π/4 in precision `px`.  Bellard's Formula
    public static func ATAN1(precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if leastNormalMagnitude != 0 {  // FIXME: this trick is dirty
            return Self.pi / 4
        }
        let apx = Swift.abs(px)
        let cached = _memoLock.withLock { ATAN1 }
        if apx <= cached.precision { return cached.value.truncated(width: apx) }
        let v:Self = Self.self == BigRat.self ? {
            let epsilon = getEpsilon(precision: px)
            var p64 = Self(0)
            for i in 0..<Int(apx.magnitude) {
                var t = Self(0)
                t -= Self(1<<5) / Self( 4 * i + 1)
                t -= Self(1<<0) / Self( 4 * i + 3)
                t += Self(1<<8) / Self(10 * i + 1)
                t -= Self(1<<6) / Self(10 * i + 3)
                t -= Self(1<<2) / Self(10 * i + 5)
                t -= Self(1<<2) / Self(10 * i + 7)
                t += Self(1<<0) / Self(10 * i + 9)
                if 0 < i {
                    t /= Self(IntType(1) << (10 * i))
                }
                p64 += i & 1 == 1 ? -t : t
                // p64.truncate(px)
                if db {
                    print("\(Self.self).ATAN1(precision:\(px)):i=\(i),t.bits=\(t)")
                }
                // t.truncate(px)
                if t < epsilon { break }
            }
            p64 /= Self(1<<8)
            return p64.truncated(width: apx)
        }() : Self(BigRat.ATAN1(precision: apx))
        _memoLock.withLock { if ATAN1.precision < apx { ATAN1 = (precision: apx, value: v) } }
        return v
    }
    /// π in precision `px`.  4*atan(1)
    public static func PI(precision px:Int=Self.precision, debug db:Bool=false)->Self {
        return ATAN1(precision: Swift.abs(px)) * 4
    }
}

extension BigFloatingPoint {
    /// √x
    public static func sqrt(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        return x.squareRoot(precision: px)
    }
    /// sqrt(x*x + y*y)
    public static func hypot(_ x:Self, _ y:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self  {
        return (x*x + y*y).squareRoot(precision:px)
    }
    /// atan2
    public static func atan2(y:Self, x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self  {
        // cf. https://en.wikipedia.org/wiki/Atan2
        //     https://www.freebsd.org/cgi/man.cgi?query=atan2
        if x.isNaN || y.isNaN { return nan }
        let ysgn  = Self(y.sign == .minus ? -1 : +1)
        let xsgn  = Self(x.sign == .minus ? -1 : +1)
        let y_x   = x.isInfinite && y.isInfinite ? ysgn * xsgn : y/x // avoid nan for ±inf/±inf
        if 0 < x {
            return atan(y_x, precision:px)
        }
        if x < 0 {
            return ysgn * (PI(precision:px) - atan(Swift.abs(y_x), precision:px))
        }
        else {  // x.isZero
            return ysgn * (
              y.isZero ? (x.sign == .minus ? PI(precision:px) : 0) : PI(precision: px)/2
            )
        }
    }
    /// self ** n where n is an integer
    public func power(_ y:IntType, precision px:Int=Self.precision, debug db:Bool=false)->Self  {
        if self.isNaN || self.isInfinite || self.isZero {
            return Self(Double.pow(self.toDouble(), Self(y).toDouble()))
        }
        if self < 0 {
            let isOdd = y & 1 == 1
            let magnitude = (-self).power(y, precision:px, debug:db)
            return isOdd ? -magnitude : +magnitude
        }
        if y == 0 { return 1 }
        if y < 0  { return 1/self.power(-y, precision:px) }
        var (i, r, x) = (y, Self(1), self)
        while i != 0 {
            if i & 1 == 1 { r *= x }
            x = (x * x).truncated(width: px*2)
            i >>= 1
        }
        return r.truncated(width:px)
    }
    /// x ** y
    public static func pow(_ x:Self, _ y:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self  {
        if x.isNaN || x.isInfinite || x.isZero || y.isNaN || y.isInfinite || y.isZero {
            return Self(Double.pow(x.toDouble(), y.toDouble()))
        }
        if Swift.abs(x) < 1   { return 1/pow(1/x, y, precision:px) }
        let (iy, fy) = y.toMixed()
        if Int.max <= iy.magnitude {
            return iy < 0 ? 0 : infinity
        }
        let ir = x.power(iy, precision:px)
        if fy.isZero {
            return px < 0 ? ir : ir.truncated(width:px)
        } else {
            if x.isLess(than:0) { return nan }
        }
        let fr = exp(log(x, precision:px*2, debug:db) * fy, precision:px*2)
        return px < 0 ? ir * fr : (ir * fr).truncated(width: px)
    }
    /// nth root of self
    public func nthroot(_ n:IntType, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if self.isNaN  { return Self.nan }
        if self.isZero { return self }
        if self == 1   { return 1 }
        if self <  0   { return -(-self).nthroot(n, precision:px) }
        return Self.pow(self, Self(n).reciprocal!, precision:px, debug:db)
    }
    /// cube root of self
    public static func cbrt(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        return x.nthroot(3, precision: px)
    }
    /// e ** x
    public static func exp(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN      { return nan }
        if x.isInfinite { return x.sign == .minus ? 0 : +infinity }
        if x.isZero     { return 1 }
        if expLimit < Swift.abs(x) {
            return x.sign == .minus ? 0 : +Self.infinity
        }
        if x.isLess(than:0) { return 1/exp(-x, precision:px, debug:db) }
        let e = E(precision: px * 2)
        let (ix, fx) = x.toMixed()
        var (ir, fr) = (e.power(ix, precision:px), Self(1))
        if !fr.isZero {
            let epsilon = getEpsilon(precision: px)
            var (n, d) = (Self(1), Self(1))
            for i in 1 ... px.magnitude {
                n = (n * fx).truncated(width:px)
                d *= Self(i)
                let t = n.divided(by:d, precision:px)
                fr += t
                if t < epsilon { break }
            }
        }
        let r = ir * fr
        return  0 < px ? r : r.truncated(width:px)
    }
    /// exp(x) - 1
    public static func expMinusOne(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN      { return nan }
        if x.isInfinite { return x.sign == .minus ? -1 : +infinity }
        if x.isZero     { return x }
        if expLimit < Swift.abs(x) {
            return x.sign == .minus ? -1 : +Self.infinity
        }
        if LN2(precision: px) <=  Swift.abs(x)  {
            return exp(x, precision:px) - 1
        }
        let epsilon = getEpsilon(precision: px)
        var (n, d, r) = (Self(1), Self(1), Self(0))
        for i in 1 ... px.magnitude {
            n *= x
            d *= Self(i)
            let t = n.divided(by:d, precision:px)
            r += t
            // compare the *magnitude*: for x < 0 this series alternates, and a
            // signed test bails out on the very first term
            if t.magnitude < epsilon { break }
        }
        return  0 < px ? r : r.truncated(width:px)
    }
    /// 2 ** x
    public static func exp2(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        // return exp(x * LN2(precision:px, debug:db), precision:px, debug:db)
        if x.isNaN      { return nan }
        if x.isInfinite { return x.sign == .minus ? 0 : +infinity }
        if x.isZero     { return 1 }
        if expLimit < Swift.abs(x) {
            return x.sign == .minus ? 0 : +Self.infinity
        }
        if x.isLess(than:0) { return 1/exp2(-x, precision:px, debug:db) }
        let (ix, fx) = x.toMixed()
        let (ir, fr) = (
          Self(2.0).power(ix, precision:px),
          exp(fx * LN2(precision:px, debug:db), precision:px, debug:db)
        )
        let r = ir * fr
        return  0 < px ? r : r.truncated(width:px)
    }
    /// binary log (base 2) -- steady but slow algorithm. use log2
    public static func binaryLog(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        if x.isLess(than:1) { return -binaryLog(1/x, precision:px) }
        if x.isEqual(to:1)  { return 0 }
        var (ilog, t) = (x.exponent, x.significand)
        if t < 1 { t *= Self(Self.radix); ilog -= 1 }
        var (offset, u) = (0, IntType(0))
        for _ in offset+1 ..< Int(px.magnitude) {
            u <<= 1
            t = (t * t).truncated(width: px)
            if 2 <= t {
                u += 1
                t /= 2
            }
        }
        let r = Self(IntType(ilog)) + Self(u) / Self(IntType(1) << Swift.abs(px))
        return 0 < px ? r : r.truncated(width: px)
    }
    /// binary log
    public static func log2(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        let r =  log(x, precision:px, debug:db) / LN2(precision:px * 2)
        return 0 < px ? r : r.truncated(width: px)
    }
    /// natural log (base e)
    public static func log(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        if x.isLess(than:1) { return -log(1/x, precision:px, debug:db) }
        if x.isEqual(to:1)  { return 0 }
        let epsilon = getEpsilon(precision: px)
        let (_, ix, fx) = x.decomposed
        var t = (fx - 1).divided(by:fx + 1, precision:px)
        let t2 = t * t
        var fr = t
        for i in 1...px.magnitude {
            t *= t2
            t.truncate(width:px)
            if db { print("\(Self.self).log:i=\(i), t=\(t), fr=\(fr)") }
            if t < epsilon { break }
            fr += t.divided(by:Self(2*i + 1), precision:px)
        }
        let r = Self(IntType(ix)) * LN2(precision: px) + 2 * fr
        return 0 < px ? r : r.truncated(width: px)
    }
    /// natural log by Newton-Raphson method
    public static func logByNewtonRaphson(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        if x.isLess(than:1) { return -log(1/x, precision:px, debug:db) }
        if x.isEqual(to:1)  { return 0 }
        let thresh = x.magnitude * getEpsilon(precision: px)
        func inner(_ y:Self)->Self {
            guard y != 1 else { return 0 }
            var x = Self(0)
            for i in 1...px.magnitude {
                let ex = exp(x, precision:px)
                let dx = 2*(y-ex).divided(by:y+ex, precision:px)
                if db {
                    print("\(Self.self).atan:i=\(i), x=\(x.truncated(width:px))")
                }
                if dx.magnitude < thresh { break }
                x += dx
                x.truncate(width:px)
            }
            return x
        }
        let (_, ix, fx) = x.decomposed
        if db { print("\(Self.self).atan:ix=\(ix), fx=\(fx)") }
        let r = Self(IntType(ix)) * LN2(precision: px) + inner(fx)
        return 0 < px ? r : r.truncated(width: px)
    }
    /// common log (base 10)
    public static func log10(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        let r =  log(x, precision:px, debug:db) / LN10(precision:px)
        return 0 < px ? r : r.truncated(width: px)
    }
    /// log(1 + x)
    public static func log1p(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN                  { return nan }
        if x.isZero                 { return x }
        if x.isInfinite             { return x.sign == .minus ? nan : +infinity }
        if (x + 1).isLess(than:0)   { return nan }
        if (x + 1).isZero           { return -infinity }
        let a = x/(x + 2)
        if db { print("\(Self.self).log1p: x = ", x, "x/(x + 2) =", a) }
        if a.magnitude == 1 && !(x is BigRat) { // possible if Self is Fixed width Integer
            if db { print("\(Self.self).log1p: resorting to BigRat") }
            return Self(BigRat.log1p(x.toBigRat(), precision:px, debug:db))
        }
        return 2*atanh(a, precision:px, debug:db)
    }
    /// normalize `x` to ±π
    public static func normalizeAngle(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        var theta = x
        let onepi = PI(precision:px)
        if theta < -2*onepi || +2*onepi < theta {
            let hp = px + Int(theta.exponent)
            if db { print("\(Self.self).wrapAngle: precision =", hp) }
            let twopi = 2*PI(precision:hp)
            if db { print("before:", theta) }
            theta = theta.remainder(dividingBy: twopi, precision:hp, round:Self.roundingRule)
            theta.truncate(width:px)
            if db { print("after:", theta) }
        }
        if theta < -onepi { theta += 2*onepi }
        if +onepi < theta { theta -= 2*onepi }
        return theta
    }
    /// - returns: `(sin(x), cos(x))`
    public static func sincos(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->(sin:Self, cos:Self) {
        if x.isZero || x.isInfinite || x.isNaN {
            return (Self(Double.sin(x.toDouble())), Self(Double.cos(x.toDouble())))
        }
        let epsilon = getEpsilon(precision: px)
        if x * x <= epsilon {
            return (x, 1)   // sin(x) == x below this point
        }
        func inner(_ x:Self)->(Self, Self) {
            if 1 < Swift.abs(x) {
                var (s, c) = inner(x/2)     // use double-angle formula to reduce x
                if c == s { return (0, 1) } // prevent error accumulation
                (s, c) = (2*s*c, c*c - s*s)
                return (s.truncated(width:px*2), c.truncated(width:px*2))
            }
            var (c, s) = (Self(0), Self(0))
            var (n, d) = (Self(1), Self(1))
            for i in 0...px {
                let t = n.divided(by:d, precision:px)
                if db {
                    print("\(Self.self).sincos: i=\(i),t=\(t)")
                }
                if i & 1 == 0 {
                    c += i & 2 == 2 ? -t : +t
                } else {
                    s += i & 2 == 2 ? -t : +t
                }
                if Swift.abs(t) < epsilon { break }
                n *= x
                n.truncate(width:px)
                d *= Self(i+1)
            }
            return (s, c)
        }
        let (s, c) = inner(Swift.abs(x) < 8 ? x : normalizeAngle(x, precision:px, debug:db))
        return 0 < px ? (s, c) : (s.truncated(width: px), c.truncated(width: px))
    }
    /// cos(x)
    public static func cos(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        return sincos(x, precision:px, debug:db).cos
    }
    /// sin(x)
    public static func sin(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        return sincos(x, precision:px, debug:db).sin
    }
    /// tan(x)
    public static func tan(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isZero || x.isInfinite || x.isNaN {
            return Self(Double.tan(x.toDouble()))
        }
        let (s, c) = sincos(x, precision:px, debug:db)
        if s.isNaN || s.isInfinite || c.isNaN || c.isInfinite {
            return Self(Double.tan(x.toDouble()))
        }
        return s.divided(by:c, precision:px)
    }
    //
    // cf. https://en.wikipedia.org/wiki/Inverse_trigonometric_functions#Infinite_series
    /// arctan
    public static func atan(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN || x.isZero { return x }
        let atan1 = ATAN1(precision: px)
        if x.isInfinite { return x.sign == .minus ? -2*atan1 : +2*atan1 }
        let epsilon = getEpsilon(precision: px)
        if x * x < epsilon { return x } // atan(x) == x below this point
        func inner(_ x:Self)->Self {
            guard x < 0.5 else {
                return x < 1
                  ? atan1 - inner((1-x).divided(by:1+x, precision:px))
                  : 2*atan1 - inner(1/x)
            }
            let x2 = x*x
            let x2p1 = 1 + x2
            var (t, r) = (Self(1), Self(1))
            for i in 1...px.magnitude {
                t *= 2 * (Self(i) * x2).divided(by:Self(2*i + 1) * x2p1, precision:px)
                r += t
                r.truncate(width:px)
                if db {
                    print("\(Self.self).atan:i=\(i) r=\(r), t.sign=\(t.sign)")
                }
                if t < epsilon { break }
            }
            return r * x.divided(by:x2p1, precision:px)
        }
        let ax = Swift.abs(x)
        if ax == 1 { return x.sign == .minus ? -atan1 : atan1 }
        var r = inner(ax)
        if 0 < px { r.truncate(width: px) }
        return x.sign == .minus ? -r : +r
    }
    /// arctan by Newton-Raphson method
    public static func atanByNewtonRaphson(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN || x.isZero { return x }
        let atan1 = ATAN1(precision: px)
        if x.isInfinite { return x.sign == .minus ? -2*atan1 : +2*atan1 }
        let epsilon = getEpsilon(precision: px)
        if x * x < epsilon { return x } // atan(x) == x below this point
        let thresh = x.magnitude * epsilon
        func inner(_ y:Self)->Self {
            // newton-raphson : x <- x - f(x)/f'(x)
            // f(x) = tan(x) - y
            // f(x)/f'(x) = (tan(x) - y)/(1/cos^2(x))
            // = tan(x)*cos^2(x) - x*cos^2(x) = sin(x)cos(x) - y*cos^2(x)
            var x = Self(0)
            for i in 1...px {
                let (s, c) = sincos(x, precision:px)
                let dx = s*c - y*c*c
                if db {
                    print("\(Self.self).atan:i=\(i), x=\(x.truncated(width:px))")
                }
                if dx.magnitude < thresh { break }
                x -= dx
            }
            return x
        }
        let ax = Swift.abs(x)
        if ax == 1 { return x.sign == .minus ? -atan1 : atan1 }
        var r = ax < 1 ? inner(ax) : 2*atan1 - inner(1/x)
        if 0 < px { r.truncate(width: px) }
        return x.sign == .minus ? -r : +r
    }
    /// arccos
    public static func acos(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self   {
        if (x - 1).isZero || 1 < Swift.abs(x) {
            return Self(Double.acos(x.toDouble()))
        }
        // print("acos:", x)
        return 2*ATAN1(precision:px) - asin(x, precision:px)
    }
    /// arcsin
    public static func asin(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self   {
        if let dx = x as? Double { return Self(Double.asin(dx)) }
        if x.isZero || 1 < Swift.abs(x) || x.isInfinite {
            return Self(Double.asin(x.toDouble()))
        }
        let a = x.divided(by:1 + sqrt(1 - x*x, precision:px), precision:px)
        return 2*atan(a, precision:px)
    }
    /// - returns: `(sinh(x), cosh(x))`
    public static func sinhcosh(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->(sinh:Self, cosh:Self) {
        if x.isZero || x.isInfinite || x.isNaN {
            return (Self(Double.sinh(x.toDouble())), Self(Double.cosh(x.toDouble())))
        }
        if 1 < x.magnitude {
            let ep = exp(x, precision:px)
            let em = ep.reciprocal!
            return ((ep - em)/2, (ep + em)/2)
        }
        let epsilon = getEpsilon(precision: px)
        if x * x <= epsilon {
            return (x, 1)   // sinh(x) == x below this point
        }
        func inner(_ x:Self)->(Self, Self) {
            var (c, s) = (Self(0), Self(0))
            var (n, d) = (Self(1), Self(1))
            for i in 0...px {
                let t = n.divided(by:d, precision:px)
                if db {
                    print("\(Self.self).sincos: i=\(i),t=:\(t)")
                }
                if i & 1 == 0 {
                    c += t
                } else {
                    s += t
                }
                if Swift.abs(t) < epsilon { break }
                n *= x
                n.truncate(width:px)
                d *= Self(i+1)
            }
            return (s, c)
        }
        let (s, c) = inner(x)
        return 0 < px ? (s, c) : (s.truncated(width: px), c.truncated(width: px))
    }
    /// hyperbolic cosine
    public static func cosh(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self   {
        return sinhcosh(x, precision:px, debug:db).cosh
    }
    /// hyperbolic sine
    public static func sinh(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self   {
        return sinhcosh(x, precision:px, debug:db).sinh
    }
    /// hyperbolic tangent
    public static func tanh(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self   {
        if x.isZero || x.isInfinite || x.isNaN {
            return Self(Double.tanh(x.toDouble()))
        }
        let (s, c) = sinhcosh(x, precision:px, debug:db)
        if s.isInfinite {
            return x.sign == .minus ? -1 : +1
        }
        return s.divided(by:c, precision:px)
    }
    /// acosh
    public static func acosh(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self   {
        if x.isLess(than: 1) { return nan }
        let a = x + sqrt(x * x - 1, precision:px, debug:db)
        return log(a, precision:px, debug:db)
    }
    /// asinh
    public static func asinh(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self   {
        if x.isZero || x.isInfinite { return x }
        if x.isLess(than:0){ return -asinh(-x, precision:px) }
        let epsilon = getEpsilon(precision: px)
        if x * x <= epsilon {
            return x    // asinh(x) == x blow this point
        }
        let a = sqrt(x * x + 1, precision:px, debug:db)
        if db { print("\(Self.self).asinh: x = ", x, "√(x*x + 1) = ", a) }
        if a.magnitude == 1 && !(x is BigRat) { // possible if Self is Fixed width Integer
            if db { print("\(Self.self).asinh: resorting to BigRat") }
            return Self(BigRat.asinh(x.toBigRat(), precision:px, debug:db))
        }
        return log(x + a, precision:px, debug:db)
    }
    /// atanh
    public static func atanh(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self   {
        if x.isZero { return x }
        if 1 <  x.magnitude { return nan }
        if 1 == x.magnitude { return x.sign == .minus ? -infinity : +infinity }
        let a = (1 + x).divided(by:1 - x, precision:px)
        if db { print("\(Self.self).atanh: x = ", x, "(1 + x)/(1 - x) =", a) }
        if a.magnitude == 1 && !(x is BigRat) { // possible if Self is Fixed width Integer
            if db { print("\(Self.self).atanh: resorting to BigRat") }
            return Self(BigRat.atanh(x.toBigRat(), precision:px, debug:db))
        }
        return log(a, precision:px, debug:db)  / 2
    }
}

extension BigFloatingPoint {
    /// √π
    public static func SQRTPI(precision px:Int=Self.precision, debug db:Bool=false)->Self {
        let apx = Swift.abs(px)
        return PI(precision:apx).squareRoot(precision:apx)
    }
    /// e ** x -- by way of `2 ** (x/log(2))`
    ///
    /// `exp()` raises `E` to the integral part of `x` by repeated squaring
    /// and a power of two denominator is left as is by `truncate(width:)`,
    /// so the operands of `BigRat` grow exponentially with the exponent.
    /// raising 2 instead keeps them exact however big the exponent gets.
    ///
    /// `exp2()` is not used as is because it would apply `expLimit` to the
    /// scaled exponent and so saturate earlier than `exp()` does.
    public static func expByExp2(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN      { return nan }
        if x.isInfinite { return x.sign == .minus ? 0 : +infinity }
        if x.isZero     { return 1 }
        if expLimit < Swift.abs(x) {
            return x.sign == .minus ? 0 : +Self.infinity
        }
        let apx = Swift.abs(px)
        if x.isLess(than:0) {
            return Self(1).divided(by:expByExp2(-x, precision:apx, debug:db), precision:apx)
        }
        // the quotient needs the extra bits because only its fractional
        // part survives into the significand of the result
        let ln2 = LN2(precision:apx + 32)
        let (ix, fx) = x.divided(by:ln2, precision:apx + 32).toMixed()
        let r = Self(2).power(ix, precision:apx) * exp(fx * ln2, precision:apx, debug:db)
        return 0 < px ? r : r.truncated(width:px)
    }
    /// e ** x -- `exp()` or `expByExp2()`, whichever is cheaper
    ///
    /// `exp()` wins while the exponent is small but its cost climbs with it,
    /// whereas `expByExp2()` is flat.  the crossover measured with `BigRat`
    /// is around 2**7 -- `BigFloat` prefers `exp()` throughout but the extra
    /// work there is negligible.
    static func expEitherWay(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        return Swift.abs(x) < 128
          ? exp(x, precision:px, debug:db) : expByExp2(x, precision:px, debug:db)
    }
    /// sin(π*x).  stays accurate even when |x| is large
    /// because only the fractional part of `x` is fed to `sin()`
    public static func sinPi(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN || x.isInfinite { return nan }
        let (ix, fx) = x.toMixed()    // x == ix + fx where |fx| < 1
        if fx.isZero { return 0 }   // sin(π*n) == 0
        let s = sin(PI(precision:px) * fx, precision:px, debug:db)
        return ix % 2 == 0 ? +s : -s
    }
    /// error function
    ///
    /// uses the cancellation-free variant of the Maclaurin series
    ///
    ///     erf(x) = 2x/√π * exp(-x*x) * Σ (2x²)ⁿ/(2n+1)‼
    ///
    /// cf. https://en.wikipedia.org/wiki/Error_function#Taylor_series
    public static func erf(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN          { return nan }
        if x.isZero         { return x }
        if x.isInfinite     { return x.sign == .minus ? -1 : +1 }
        if x.isLess(than:0) { return -erf(-x, precision:px, debug:db) }
        let apx = Swift.abs(px)
        let wpx = apx + 32
        let x2  = x * x
        // erfc(x) is already below the epsilon beyond this point so erf(x) == 1
        if Self(apx + 1) * LN2(precision:wpx) < x2 { return 1 }
        let epsilon = getEpsilon(precision: wpx)
        var (t, s) = (Self(1), Self(1))
        for i in 1 ... (4 * apx + 64) {
            t = (2 * t * x2).divided(by:Self(2*i + 1), precision:wpx)
            t.truncate(width:wpx)
            s += t
            s.truncate(width:wpx)
            if db { print("\(Self.self).erf: i=\(i), t=\(t.toDouble()), s=\(s.toDouble())") }
            if t < s * epsilon { break }
        }
        // divide by exp(+x*x) rather than multiply by exp(-x*x) --
        // the latter loses bits because `exp()` negates via `1/exp(-x)`
        let r = (2 * x * s)
          .divided(by:expEitherWay(x2, precision:wpx) * SQRTPI(precision:wpx), precision:wpx)
        return 0 < px ? r : r.truncated(width:px)
    }
    /// complementary error function -- `1 - erf(x)` without cancellation
    ///
    /// for larger `x` the continued fraction of the incomplete gamma function
    ///
    ///     erfc(x) = Γ(½,x²)/√π
    ///
    /// is used instead.  cf. https://dlmf.nist.gov/8.9
    public static func erfc(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN      { return nan }
        if x.isInfinite { return x.sign == .minus ? 2 : 0 }
        if x.isZero     { return 1 }
        let apx = Swift.abs(px)
        let x2  = x * x
        // erfc(x) ~ exp(-x*x) so 1 - erf(x) costs us x*x*log2(e) bits.
        // as long as that is affordable the series above is the faster way
        if x.isLess(than:1) || x2 < Self(apx) * LN2(precision:apx + 32) {
            // this branch keeps `lost` below `apx`.  fall back to that bound
            // when `toDouble()` cannot tell us how large x*x actually is
            let d2   = x2.toDouble()
            let lost = x.isLess(than:0) ? 0
              : d2.isFinite ? Swift.min(apx, Int(d2 * 1.4426950408889634) + 1) : apx
            let wpx  = apx + lost + 32
            if db { print("\(Self.self).erfc: x=\(x.toDouble()), lost=\(lost) bits") }
            let r = 1 - erf(x, precision:wpx, debug:db)
            return 0 < px ? r : r.truncated(width:px)
        }
        //  Γ(a,z) = exp(-z)*z**a / (z+1-a - 1(1-a)/(z+3-a - 2(2-a)/(z+5-a - …)))
        //  where a = ½ and z = x*x.  evaluated by the modified Lentz method
        let wpx     = apx + 32
        let epsilon = getEpsilon(precision: wpx)
        let tiny    = getEpsilon(precision: wpx * 2)
        let half    = Self(1)/2
        var b = x2 + half           // z + 1 - a
        var c = Self(1).divided(by:tiny, precision:wpx)
        var d = Self(1).divided(by:b,    precision:wpx)
        var h = d
        for i in 1 ... (4 * apx + 64) {
            let an = -Self(i) * (Self(i) - half)
            b += 2
            d = an * d + b; if d.isZero { d = tiny }
            c = b + an.divided(by:c, precision:wpx); if c.isZero { c = tiny }
            d = Self(1).divided(by:d, precision:wpx)
            d.truncate(width:wpx)
            c.truncate(width:wpx)
            let del = d * c
            h = (h * del).truncated(width:wpx)
            if db { print("\(Self.self).erfc: i=\(i), del=\(del.toDouble())") }
            if (del - 1).magnitude < epsilon { break }
        }
        // erfc(x) = Γ(½,x²)/√π = x * h / (exp(x²) * √π)
        let r = (x * h)
          .divided(by:expEitherWay(x2, precision:wpx) * SQRTPI(precision:wpx), precision:wpx)
        return 0 < px ? r : r.truncated(width:px)
    }
    /// log(Γ(x)) for `1 <= x` by Spouge's approximation
    ///
    ///     Γ(z+1) = (z+a)**(z+½) * exp(-(z+a)) * (c₀ + Σ cₖ/(z+k))
    ///     c₀ = √(2π), cₖ = (-1)**(k-1)/(k-1)! * (a-k)**(k-½) * exp(a-k)
    ///
    /// cf. https://en.wikipedia.org/wiki/Spouge%27s_approximation
    ///
    /// every term is scaled by `exp(-a)` -- that is, `U = exp(-a) * S` is
    /// summed instead of `S` so that `exp(a-k)` never has to be built.
    /// `log(S)` is then simply `a + log(U)` which cancels the `-a` in `-(z+a)`:
    ///
    ///     log(Γ(z+1)) = (z+½)log(z+a) - z + log(U)
    ///
    /// the relative error is bounded by `a**-½ * (2π)**-(a+½)` hence
    /// `a =~ 0.3773 * precision`.  since the terms are as large as
    /// `exp(1.28*a)` while they cancel each other down to `exp(-a)`,
    /// `2*a` extra bits are needed to work with.
    public static func spougeLogGamma(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        let apx = Swift.abs(px)
        let a   = Int(Double(apx) * 0.3773) + 4
        let wpx = apx + 2*a + 32
        let z   = x - 1
        let e   = E(precision:wpx)
        var s   = Self(0)       // U = exp(-a) * S
        var fct = Self(1)       // (k-1)!
        var emk = Self(1)       // exp(-k)
        for k in 1 ..< a {
            emk = emk.divided(by:e, precision:wpx)
            emk.truncate(width:wpx)
            let ak = Self(a - k)
            var ck = ak.power(IntType(k - 1), precision:wpx) * ak.squareRoot(precision:wpx)
            ck = (ck * emk).divided(by:fct, precision:wpx)
            ck.truncate(width:wpx)
            let t = ck.divided(by:z + Self(k), precision:wpx)
            s += k & 1 == 1 ? +t : -t
            s.truncate(width:wpx)
            if db { print("\(Self.self).spougeLogGamma: k=\(k), t=\(t.toDouble()), s=\(s.toDouble())") }
            fct *= Self(k)
        }
        emk = emk.divided(by:e, precision:wpx)  // exp(-a)
        emk.truncate(width:wpx)
        s += (2 * PI(precision:wpx)).squareRoot(precision:wpx) * emk    // c₀ * exp(-a)
        s.truncate(width:wpx)
        let za = z + Self(a)
        let r  = (z + Self(1)/2) * log(za, precision:wpx, debug:db) - z
          + log(s, precision:wpx, debug:db)
        return 0 < px ? r : r.truncated(width:px)
    }
    /// log(|Γ(x)|).  cf. `signGamma(_:)` for the sign
    public static func logGamma(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN      { return nan }
        if x.isInfinite { return +infinity }
        let apx = Swift.abs(px)
        let wpx = apx + 32
        let (ix, fx) = x.toMixed()
        if fx.isZero && ix <= 0 { return +infinity }    // poles at 0, -1, -2, …
        var r:Self
        if x.isLess(than:Self(1)/2) {
            // reflection formula: Γ(x)Γ(1-x) = π/sin(πx)
            r = log(PI(precision:wpx), precision:wpx, debug:db)
              - log(sinPi(x, precision:wpx, debug:db).magnitude, precision:wpx, debug:db)
              - logGamma(1 - x, precision:wpx, debug:db)
        } else if x.isLess(than:1) {
            // Γ(x) = Γ(x+1)/x -- Spouge's approximation wants 1 <= x
            r = logGamma(x + 1, precision:wpx, debug:db) - log(x, precision:wpx, debug:db)
        } else {
            r = spougeLogGamma(x, precision:wpx, debug:db)
        }
        return 0 < px ? r : r.truncated(width:px)
    }
    /// Γ(x)
    public static func gamma(_ x:Self, precision px:Int=Self.precision, debug db:Bool=false)->Self {
        if x.isNaN      { return nan }
        if x.isInfinite { return x.sign == .minus ? nan : +infinity }
        let apx = Swift.abs(px)
        let wpx = apx + 32
        let (ix, fx) = x.toMixed()
        if fx.isZero {
            if ix == 0  { return x.sign == .minus ? -infinity : +infinity }
            if ix <  0  { return nan }  // poles
            if ix <= 1024 {             // Γ(n) == (n-1)! -- exact and fast
                var r = Self(1)
                if 2 < ix { for i in 2 ..< Int(ix) { r *= Self(i) } }
                return 0 < px ? r : r.truncated(width:px)
            }
        }
        if x.isLess(than:Self(1)/2) {
            // reflection formula: Γ(x) = π/(sin(πx)Γ(1-x))
            let d = sinPi(x, precision:wpx, debug:db) * gamma(1 - x, precision:wpx, debug:db)
            let r = PI(precision:wpx).divided(by:d, precision:wpx)
            return 0 < px ? r : r.truncated(width:px)
        }
        let lg = logGamma(x, precision:wpx, debug:db)
        if expLimit < lg { return +infinity }
        let r = exp(lg, precision:wpx, debug:db)
        return 0 < px ? r : r.truncated(width:px)
    }
}

extension FloatingPoint where Self:DoubleConvertible {
    public func toBigRat()->BigRat {
        return self as? BigRat ?? BigRat(self.toDouble())
    }
    public func toString(_ format:BigNum.Format = .point, radix:Int = 10)->String {
        return self.toBigRat().toString(format, radix:radix)
    }
}

// Make BigFloatingPoint conform to the two protocols at the top of this file.
// The `precision:`-taking versions above ought to satisfy them by way of their
// default arguments, but as of Swift 5 they do not, so each requirement needs
// the one-line shim below.
extension BigFloatingPoint {
    public static func exp(_ x:Self) -> Self {
        return         exp(x, precision:Self.precision, debug:false)
    }
    public static func expMinusOne(_ x:Self) -> Self {
        return         expMinusOne(x, precision:Self.precision, debug:false)
    }
    public static func exp2(_ x: Self) -> Self {
        return         exp2(x, precision:Self.precision, debug:false)
    }
    public static func cosh(_ x:Self) -> Self {
        return         cosh(x, precision:Self.precision, debug:false)
    }
    public static func sinh(_ x:Self) -> Self {
        return         sinh(x, precision:Self.precision, debug:false)
    }
    public static func tanh(_ x:Self) -> Self {
        return         tanh(x, precision:Self.precision, debug:false)
    }
    public static func cos(_ x:Self) -> Self {
        return         cos(x, precision:Self.precision, debug:false)
    }
    public static func sin(_ x:Self) -> Self {
        return         sin(x, precision:Self.precision, debug:false)
    }
    public static func tan(_ x:Self) -> Self {
        return         tan(x, precision:Self.precision, debug:false)
    }
    public static func log(_ x:Self) -> Self {
        return         log(x, precision:Self.precision, debug:false)
    }
    public static func log(onePlus x:Self) -> Self {
        return         log1p(      x, precision:Self.precision, debug:false)
    }
    public static func log2(_ x:Self) -> Self {
        return         log2(x, precision:Self.precision, debug:false)
    }
    public static func log10(_ x:Self) -> Self {
        return         log10(x, precision:Self.precision, debug:false)
    }
    public static func acosh(_ x:Self) -> Self {
        return         acosh(x, precision:Self.precision, debug:false)
    }
    public static func asinh(_ x:Self) -> Self {
        return         asinh(x, precision:Self.precision, debug:false)
    }
    public static func atanh(_ x:Self) -> Self {
        return         atanh(x, precision:Self.precision, debug:false)
    }
    public static func acos(_ x:Self) -> Self {
        return         acos(x, precision:Self.precision, debug:false)
    }
    public static func asin(_ x:Self) -> Self {
        return         asin(x, precision:Self.precision, debug:false)
    }
    public static func atan(_ x:Self) -> Self {
        return         atan(x, precision:Self.precision, debug:false)
    }
    public static func pow(_ x: Self, _ y: Self) -> Self {
        return         pow(x, y, precision:Self.precision, debug:false)
    }
    public static func pow(_ x:Self, _ n:Int) -> Self {
        return x.power(IntType(n), precision:Self.precision, debug:false)
    }
    public static func sqrt(_ x:Self) -> Self {
        return         sqrt(x, precision:Self.precision, debug:false)
    }
    public static func root(_ x:Self, _ n:Int) -> Self {
        return x.nthroot(IntType(n), precision:Self.precision, debug:false)
    }
    public static func hypot(_ y: Self, _ x: Self) -> Self {
        return hypot(y, x, precision:Self.precision, debug:false);
    }
    public static func atan2(y: Self, x: Self) -> Self { // argument labels needed
        return atan2(y:y, x:x, precision:Self.precision, debug:false);
    }
    public static func erf(_ x: Self) -> Self {
        return         erf(x, precision:Self.precision, debug:false)
    }
    public static func erfc(_ x: Self) -> Self {
        return         erfc(x, precision:Self.precision, debug:false)
    }
    public static func gamma(_ x: Self) -> Self {
        return         gamma(x, precision:Self.precision, debug:false)
    }
    public static func logGamma(_ x: Self) -> Self {
        return         logGamma(x, precision:Self.precision, debug:false)
    }
}

extension BigRat : ElementaryFunctions, RealFunctions {}
extension BigFloat : ElementaryFunctions, RealFunctions {}
