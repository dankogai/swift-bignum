extension BigFloatingPoint {
    // constants
    /// √2
    public static func SQRT2(precision px:Int=Self.precision, debug:Bool=false)->Self {
        let apx = Swift.abs(px)
        if apx <= SQRT2.precision { return SQRT2.value.truncated(width: apx) }
        SQRT2.precision = apx
        SQRT2.value = Self(2).squareRoot(precision: apx)
        return SQRT2.value
    }
    /// euler's constant
    public static func E(precision px:Int=Self.precision, debug:Bool=false)->Self {
        let apx = Swift.abs(px)
        if apx <= E.precision { return E.value.truncated(width: apx) }
        E.precision = apx
        E.value = E.value is BigRat ? {
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
        return E.value
    }
    /// log(2)
    public static func LN2(precision px:Int=Self.precision, debug:Bool = false)->Self {
        let apx = Swift.abs(px)
        if apx <= LN2.precision { return LN2.value.truncated(width: apx) }
        LN2.precision = apx
        LN2.value = LN2.value is BigRat ? {
            let epsilon = getEpsilon(precision: px)
            var (t, r) = (Self(1)/Self(3), Self(1)/Self(3))
            for i in 1...px.magnitude {
                t *= Self(1)/Self(9)
                if debug { print("\(Self.self).LN2: i=\(i), r=~\(r)") }
                if t < epsilon { break }
                r += t / Self(2 * i + 1)
            }
            return (2*r).truncated(width: apx)
        }() : Self(BigRat.LN2(precision: apx))
        return LN2.value
    }
    /// log(10)
    public static func LN10(precision px:Int=Self.precision, debug:Bool=false)->Self {
        let apx = Swift.abs(px)
        if apx <= LN10.precision { return LN10.value.truncated(width: apx) }
        LN10.precision = apx
        LN10.value = Self.log(10, precision:apx)
        return LN10.value
    }
    /// π/4 in precision `px`.  Bellard's Formula
    public static func ATAN1(precision px:Int=Self.precision, debug:Bool=false)->Self {
        if leastNormalMagnitude != 0 {  // FIXME: this trick is dirty
            return Self.pi / 4
        }
        let apx = Swift.abs(px)
        if apx <= ATAN1.precision { return ATAN1.value.truncated(width: apx) }
        ATAN1.precision = apx
        ATAN1.value = ATAN1.value is BigRat ? {
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
                if debug {
                    print("\(Self.self).ATAN1(precision:\(px)):i=\(i),t.bits=\(t)")
                }
                // t.truncate(px)
                if t < epsilon { break }
            }
            p64 /= Self(1<<8)
            return p64.truncated(width: apx)
        }() : Self(BigRat.ATAN1(precision: apx))
        return ATAN1.value
    }
    /// π in precision `px`.  4*atan(1)
    public static func PI(precision px:Int=Self.precision, debug:Bool=false)->Self {
        return ATAN1(precision: Swift.abs(px)) * 4
    }
}

extension BigFloatingPoint {
    /// √x
    public static func sqrt(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        return x.squareRoot(precision: px)
    }
    /// sqrt(x*x + y*y)
    public static func hypot(_ x:Self, _ y:Self, precision px:Int=Self.precision, debug:Bool=false)->Self  {
        return (x*x + y*y).squareRoot(precision:px)
    }
    /// atan2
    public static func atan2(y:Self, x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self  {
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
    public func power(_ y:IntType, precision px:Int=Self.precision, debug:Bool=false)->Self  {
        if self.isNaN || self.isInfinite || self.isZero {
            return Self(Double.pow(self.asDouble, Self(y).asDouble))
        }
        if self < 0 {
            let isOdd = y & 1 == 1
            let magnitude = (-self).power(y, precision:px, debug:debug)
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
    public static func pow(_ x:Self, _ y:Self, precision px:Int=Self.precision, debug:Bool=false)->Self  {
        if x.isNaN || x.isInfinite || x.isZero || y.isNaN || y.isInfinite || y.isZero {
            return Self(Double.pow(x.asDouble, y.asDouble))
        }
        if Swift.abs(x) < 1   { return 1/pow(1/x, y, precision:px) }
        let (iy, fy) = y.asMixed
        if Int.max <= iy.magnitude {
            return iy < 0 ? 0 : infinity
        }
        let ir = x.power(iy, precision:px)
        if fy.isZero {
            return px < 0 ? ir : ir.truncated(width:px)
        } else {
            if x.isLess(than:0) { return nan }
        }
        let fr = exp(log(x, precision:px*2) * fy, precision:px*2)
        return px < 0 ? ir * fr : (ir * fr).truncated(width: px)
    }
    /// nth root of self
    public func nthroot(_ n:IntType, precision px:Int=Self.precision, debug:Bool=false)->Self {
        if self.isNaN  { return Self.nan }
        if self.isZero { return self }
        if self == 1   { return 1 }
        if self <  0   { return -(-self).nthroot(n, precision:px) }
        return Self.pow(self, Self(1)/Self(n), precision:px)
    }
    /// cube root of self
    public static func cbrt(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        return x.nthroot(3, precision: px)
    }
    /// e ** x
    public static func exp(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        if x.isNaN      { return nan }
        if x.isInfinite { return x.sign == .minus ? 0 : +infinity }
        if x.isZero     { return 1 }
        if expLimit < Swift.abs(x) {
            return x.sign == .minus ? 0 : +Self.infinity
        }
        if x.isLess(than:0) { return 1/exp(-x, precision:px, debug:debug) }
        let e = E(precision: px * 2)
        let (ix, fx) = x.asMixed
        var (ir, fr) = (e.power(ix, precision:px), Self(1))
        if !fr.isZero {
            let epsilon = getEpsilon(precision: px)
            var (n, d) = (Self(1), Self(1))
            for i in 1 ... px.magnitude {
                n = (n * fx).truncated(width: px)
                d *= Self(i)
                let t = n / d
                if t < epsilon { break }
                fr = (fr + t).truncated(width: px)
            }
        }
        let r = ir * fr
        return  0 < px ? r : r.truncated(width:px)
    }
    /// exp(x) - 1
    public static func expMinusOne(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
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
            let t = n / d
            r += t
            if t < epsilon { break }
            n.truncate(width: px * 2)
            r.truncate(width: px * 2)
        }
        return  0 < px ? r : r.truncated(width:px)
    }
    /// 2 ** x
    public static func exp2(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        // return exp(x * LN2(precision:px, debug:debug), precision:px, debug:debug)
        if x.isNaN      { return nan }
        if x.isInfinite { return x.sign == .minus ? 0 : +infinity }
        if x.isZero     { return 1 }
        if expLimit < Swift.abs(x) {
            return x.sign == .minus ? 0 : +Self.infinity
        }
        if x.isLess(than:0) { return 1/exp2(-x, precision:px, debug:debug) }
        let (ix, fx) = x.asMixed
        let (ir, fr) = (
            Self(2.0).power(ix, precision:px),
            exp(fx * LN2(precision:px, debug:debug), precision:px, debug:debug)
        )
        let r = ir * fr
        return  0 < px ? r : r.truncated(width:px)
    }
    /// binary log (base 2) -- steady but slow algorithm. use log2
    public static func binaryLog(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
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
    public static func log2(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        let r =  log(x, precision:px, debug:debug) / LN2(precision:px * 2)
        return 0 < px ? r : r.truncated(width: px)
    }
    /// natural log (base e)
    public static func log(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        if x.isLess(than:1) { return -log(1/x, precision:px, debug:debug) }
        if x.isEqual(to:1)  { return 0 }
        let epsilon = getEpsilon(precision: px)
        let (_, ix, fx) = x.decomposed
        var t = (fx - 1) / (fx + 1)
        let t2 = t * t
        var fr = t
        for i in 1...px.magnitude {
            t = (t * t2).truncated(width: px)
            if debug { print("\(Self.self).log:i=\(i), t=\(t),fr=\(fr)") }
            if t < epsilon { break }
            fr = (fr + t / Self(2*i + 1)).truncated(width: px)
        }
        let r = Self(IntType(ix)) * LN2(precision: px) + 2 * fr
        return 0 < px ? r : r.truncated(width: px)
    }
    /// common log (base 10)
    public static func log10(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        let r =  log(x, precision:px, debug:debug) / LN10(precision:px)
        return 0 < px ? r : r.truncated(width: px)
    }
    /// log(1 + x)
    public static func log1p(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        if x.isNaN                  { return nan }
        if x.isZero                 { return x }
        if x.isInfinite             { return x.sign == .minus ? nan : +infinity }
        if (x + 1).isLess(than:0)   { return nan }
        if (x + 1).isZero           { return -infinity }
        let a = x/(x + 2)
        if debug { print("\(Self.self).log1p: x = ", x, "x/(x + 2) =", a) }
        if a.magnitude == 1 && !(x is BigRat) { // possible if Self is Fixed width Integer
            if debug { print("\(Self.self).log1p: resorting to BigRat") }
            return Self(BigRat.log1p(x.asBigRat, precision:px, debug:debug))
        }
        return 2*atanh(a, precision:px, debug:debug)
    }
    /// normalize `x` to ±π
    public static func normalizeAngle(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        var theta = x
        let onepi = PI(precision:px)
        if theta < -2*onepi || +2*onepi < theta {
            let hp = px + Int(theta.exponent)
            if debug { print("\(Self.self).wrapAngle: precision =", hp) }
            let twopi = 2*PI(precision:hp)
            if debug { print("before:", theta) }
            theta = theta.remainder(dividingBy: twopi, precision:hp, round:Self.roundingRule)
            theta.truncate(width:px)
            if debug { print("after:", theta) }
        }
        if theta < -onepi { theta += 2*onepi }
        if +onepi < theta { theta -= 2*onepi }
        return theta
    }
    /// - returns: `(sin(x), cos(x))`
    public static func sincos(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->(sin:Self, cos:Self) {
        if x.isZero || x.isInfinite || x.isNaN {
            return (Self(Double.sin(x.asDouble)), Self(Double.cos(x.asDouble)))
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
                let t = n / d
                if debug {
                    print("\(Self.self).sincos: i=\(i),t=\(t)")
                }
                if i & 1 == 0 {
                    c += i & 2 == 2 ? -t : +t
                } else {
                    s += i & 2 == 2 ? -t : +t
                }
                if Swift.abs(t) < epsilon { break }
                n = (n * x).truncated(width: px)
                d *= Self(i+1)
            }
            return (s, c)
        }
        let (s, c) = inner(Swift.abs(x) < 8 ? x : normalizeAngle(x, precision:px, debug:debug))
        return 0 < px ? (s, c) : (s.truncated(width: px), c.truncated(width: px))
    }
    /// cos(x)
    public static func cos(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        return sincos(x, precision:px, debug:debug).cos
    }
    /// sin(x)
    public static func sin(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        return sincos(x, precision:px, debug:debug).sin
    }
    /// tan(x)
    public static func tan(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        if x.isZero || x.isInfinite || x.isNaN {
            return Self(Double.tan(x.asDouble))
        }
        let (s, c) = sincos(x, precision:px, debug:debug)
        if s.isNaN || s.isInfinite || c.isNaN || c.isInfinite {
            return Self(Double.tan(x.asDouble))
        }
        return s / c
    }
    //
    // cf. https://en.wikipedia.org/wiki/Inverse_trigonometric_functions#Infinite_series
    /// arctan
    public static func atan(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self {
        if x.isNaN || x.isZero { return x }
        let atan1 = ATAN1(precision: px)
        if x.isInfinite { return x.sign == .minus ? -2*atan1 : +2*atan1 }
        let epsilon = getEpsilon(precision: px)
        if x * x < epsilon { return x } // atan(x) == x below this point
        func inner_atan(_ x:Self)->Self {
            guard x < 0.5 else {
                return x < 1 ? atan1 - inner_atan((1-x)/(1+x)) : 2*atan1 - inner_atan(1/x)
            }
            let x2 = x*x
            let x2p1 = 1 + x2
            var (t, r) = (Self(1), Self(1))
            for i in 1...px.magnitude {
                t *= 2 * (Self(i) * x2) / (Self(2 * i + 1) * x2p1)
                t.truncate(width:px * 2)
                r += t
                r.truncate(width:px * 2)
                if debug {
                    print("\(Self.self).atan:i=\(i) r=\(r), t.sign=\(t.sign)")
                }
                if t < epsilon { break }
            }
            return r * x / x2p1
        }
        let ax = Swift.abs(x)
        if ax == 1 { return x.sign == .minus ? -atan1 : atan1 }
        var r = inner_atan(ax)
        if 0 < px { r.truncate(width: px) }
        return x.sign == .minus ? -r : +r
    }
    /// arccos
    public static func acos(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self   {
        if (x - 1).isZero || 1 < Swift.abs(x) {
            return Self(Double.acos(x.asDouble))
        }
        // print("acos:", x)
        return PI(precision: px)/2 - asin(x, precision:px)
    }
    /// arcsin
    public static func asin(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self   {
        if let dx = x as? Double { return Self(Double.asin(dx)) }
        if x.isZero || 1 < Swift.abs(x) || x.isInfinite {
            return Self(Double.asin(x.asDouble))
        }
        let a = x / (1 + sqrt(1 - x * x))
        return 2 * atan(a, precision:px)
    }
    /// - returns: `(sinh(x), cosh(x))`
    public static func sinhcosh(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->(sinh:Self, cosh:Self) {
        if x.isZero || x.isInfinite || x.isNaN {
            return (Self(Double.sinh(x.asDouble)), Self(Double.cosh(x.asDouble)))
        }
        if 1 < x.magnitude {
            let ep = exp(x, precision:px)
            let em = 1/ep
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
                let t = n / d
                if debug {
                    print("\(Self.self).sincos: i=\(i),t=:\(t)")
                }
                if i & 1 == 0 {
                    c += t
                } else {
                    s += t
                }
                if Swift.abs(t) < epsilon { break }
                n = (n * x).truncated(width: px)
                d *= Self(i+1)
            }
            return (s, c)
        }
        let (s, c) = inner(x)
        return 0 < px ? (s, c) : (s.truncated(width: px), c.truncated(width: px))
    }
    /// hyperbolic cosine
    public static func cosh(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self   {
        return sinhcosh(x, precision:px, debug:debug).cosh
    }
    /// hyperbolic sine
    public static func sinh(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self   {
        return sinhcosh(x, precision:px, debug:debug).sinh
    }
    /// hyperbolic tangent
    public static func tanh(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self   {
        if x.isZero || x.isInfinite || x.isNaN {
            return Self(Double.tanh(x.asDouble))
        }
        let (s, c) = sinhcosh(x, precision:px, debug:debug)
        if s.isInfinite {
            return x.sign == .minus ? -1 : +1
        }
        return s / c
    }
    /// acosh
    public static func acosh(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self   {
        if x.isLess(than: 1) { return nan }
        let a = x + sqrt(x * x - 1, precision:px)
        return log(a, precision:px)
    }
    /// asinh
    public static func asinh(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self   {
        if x.isZero || x.isInfinite { return x }
        if x.isLess(than:0){ return -asinh(-x, precision:px) }
        let epsilon = getEpsilon(precision: px)
        if x * x <= epsilon {
            return x    // asinh(x) == x blow this point
        }
        let a = sqrt(x * x + 1, precision:px)
        if debug { print("\(Self.self).asinh: x = ", x, "√(x*x + 1) = ", a) }
        if a.magnitude == 1 && !(x is BigRat) { // possible if Self is Fixed width Integer
            if debug { print("\(Self.self).asinh: resorting to BigRat") }
            return Self(BigRat.asinh(x.asBigRat, precision:px, debug:debug))
        }
        return log(x + a, precision:px)
    }
    /// atanh
    public static func atanh(_ x:Self, precision px:Int=Self.precision, debug:Bool=false)->Self   {
        if x.isZero { return x }
        if 1 <  x.magnitude { return nan }
        if 1 == x.magnitude { return x.sign == .minus ? -infinity : +infinity }
        let a = (1 + x)/(1 - x)
        if debug { print("\(Self.self).atanh: x = ", x, "(1 + x)/(1 - x) =", a) }
        if a.magnitude == 1 && !(x is BigRat) { // possible if Self is Fixed width Integer
            if debug { print("\(Self.self).atanh: resorting to BigRat") }
            return Self(BigRat.atanh(x.asBigRat, precision:px, debug:debug))
        }
        return log(a, precision:px, debug:debug)  / 2
    }
}

extension FloatingPoint where Self:DoubleConvertible {
    public var asBigRat : BigRat {
        return self as? BigRat ?? BigRat(self.asDouble)
    }
    public func toFloatingPointString(radix:Int = 10)->String {
        return self.asBigRat.toFloatingPointString(radix:radix)
    }
}

// make BigFloatingPoint conform to ElementaryFunction and RealFunctions
// above extention supposed to suffice but as of Swift 5 we need the shim below
import RealModule
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
    //: mark todo
    public static func erf(_ x: Self) -> Self {
        fatalError("yet to be implemented");
    }
    public static func erfc(_ x: Self) -> Self {
        fatalError("yet to be implemented");
    }
    public static func gamma(_ x: Self) -> Self {
        fatalError("yet to be implemented");
    }
    public static func logGamma(_ x: Self) -> Self {
        fatalError("yet to be implemented");
    }
}

extension BigRat : ElementaryFunctions, RealFunctions {}
extension BigFloat : ElementaryFunctions, RealFunctions {}
