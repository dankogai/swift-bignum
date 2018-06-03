extension BigNum {
    public static var constants = [String:(value:Any,precision:Int)]()
}
// constants
extension RationalType {
    public static var typeName:String {
        return String(describing: type(of:Self.zero))
    }
    public static func getSetConstant(_ name:String, precision:Int, getter:(Int)->Self) -> Self {
        let k = "\(Self.typeName).\(name)"
        let px = Swift.abs(precision)
        // debugPrint("\(k):\(px)")
        if let v = BigNum.constants[k] {
            if px <= v.precision { return (v.value as! Self).truncated(width: px)}
        }
        let v = getter(px)
        BigNum.constants[k] = (value:v, precision:px)
        return v
    }
    /// √2
    public static func SQRT2(precision px:Int = Int64.bitWidth)->Self {
        return getSetConstant("SQRT2", precision:px) {
            Self(2.0).squareRoot(precision: $0)
        }
    }
    /// euler's constant
    public static func E(precision px:Int = Int64.bitWidth)->Self {
        return getSetConstant("E", precision:px) {
            Self.exp(1, precision:$0)
        }
    }
    /// log(2)
    public static func LN2(precision px:Int = Int64.bitWidth, debug:Bool = false)->Self {
        return getSetConstant("LN2", precision:px) {
            let epsilon = 1 / Self(BigInt(1) << px)
            var (t, r) = (Self(1, 3), Self(1, 3))
            for i in 1...px {
                t *= Self(1, 9)
                t.truncate(width: $0)
                r += t / Self(2 * i + 1)
                if debug {
                    print("\(typeName).LN2: i=\(i), r=~\(r.asDouble)")
                }
                r.truncate(width: $0)
                if t < epsilon { break }
            }
            r.truncate(width: $0)
            return 2*r
        }
    }
    /// log(10)
    public static func LN10(precision px:Int = Int64.bitWidth)->Self {
        return getSetConstant("LN10", precision:px) {
            Self.log(10, precision:$0)
        }
    }
    /// π/4 in precision `px`.  Bellard's Formula
    public static func ATAN1(precision px:Int = Int64.bitWidth, verbose:Bool=false)->Self {
        return getSetConstant("ATAN1", precision: px) {
            let epsilon = BigInt(1).over(1 << px.magnitude)
            var p64 = Self(0)
            for i in 0..<Int($0.magnitude) {
                var t = Self(0)
                t -= Self(1<<5) / Self( 4 * i + 1)
                t -= Self(1<<0) / Self( 4 * i + 3)
                t += Self(1<<8) / Self(10 * i + 1)
                t -= Self(1<<6) / Self(10 * i + 3)
                t -= Self(1<<2) / Self(10 * i + 5)
                t -= Self(1<<2) / Self(10 * i + 7)
                t += Self(1<<0) / Self(10 * i + 9)
                if 0 < i {
                    t /= Self(BigInt(1) << (10 * i))
                }
                p64 += i & 1 == 1 ? -t : t
                // p64.truncate(px)
                if verbose {
                    print("ATAN1(precision:\(px)):i=\(i),t=\(t.asDouble)")
                }
                // t.truncate(px)
                if t < Self(epsilon) { break }
            }
            p64 /= Self(1<<8)
            return p64.truncated(width: $0)
        }
    }
    /// π in precision `px`.  4*atan(1)
    public static func PI(precision px:Int = Int64.bitWidth)->Self {
        return 4*ATAN1(precision:px)
    }
}
// tgmath for RationalType
extension RationalType {
    /// √x
    public static func sqrt(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        return x.squareRoot(precision: px)
    }
    /// x ** y
    public static func pow(_ x:Self, _ y:Self, precision px:Int = Int64.bitWidth)->Self  {
        if x.isNaN || x.isInfinite || x.isZero || y.isNaN || y.isInfinite || y.isZero {
            return Self(Double.pow(x.asDouble, y.asDouble))
        }
        if x.magnitude.isLess(than:1)   { return pow(1/x, y, precision:px) }
        if y.isLess(than:0)             { return 1/pow(x, -y, precision:px) }
        let (iy, fy) = y.asMixed
        let ir = BigInt(x.num).power(Int(iy)).over(BigInt(x.den).power(Int(iy)))
        if fy.isZero {
            return px < 0 ? Self(ir) : Self(ir).truncated(width:px)
        } else {
            if x.isLess(than:0) { return nan }
        }
        return exp(log(x, precision:px) * y, precision:px)
    }
    /// e ** x
    public static func exp(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        if x.isNaN      { return nan }
        if x.isInfinite { return x.sign == .minus ? -infinity : +infinity }
        if x.isZero     { return 1 }
        if x.isLess(than:0) { return 1/exp(-x, precision:px) }
        if 1 < x.magnitude  { return exp(1/x, precision:px) }
        let epsilon = BigInt(1).over(1 << px.magnitude)
        var (r, n, d) = (BigRat(1), BigRat(1), BigInt(1))
        for i in 1 ... Int(px.magnitude) {
            n *= x.asBigRat
            d *= BigInt(i)
            let t = n / d
            r += t
            if t < epsilon { break }
        }
        if 0 < px { r.truncate(width:px) }
        return Self(r)
    }
    /// exp(x) - 1
    public static func exp1m(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        return exp(x, precision:px) - 1
    }
    /// binary log (base 2) -- steady but slow algorithm. use log2
    static func binaryLog(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        if x.isLess(than:1) { return -binaryLog(1/x, precision:px) }
        if x.isEqual(to:1)  { return zero }
        var (ilog, t) = (x.exponent, x.significand)
        if t < 1 { t *= Self(Self.radix); ilog -= 1 }
        var  u = Element(0)
        for _ in 0 ..< px.magnitude {
            u <<= 1
            t *= t
            if 2 <= t {
                u += 1
                t /= 2
            }
            t.truncate(width:px)
        }
        var r = Self(ilog) + Self(u).over(1 << Swift.abs(px))
        if 0 < px { r.truncate(width: px) }
        return r
    }
    // binary log
    public static func log2(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        var r =  log(x, precision:px) / LN2(precision:px * 2)
        if 0 < px { r.truncate(width: px) }
        return r
    }
    /// natural log (base e)
    public static func log(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        if x.isLess(than:1) { return -log(1/x, precision:px) }
        if x.isEqual(to:1)  { return zero }
        let epsilon = Self(BigInt(1).over(1 << px.magnitude))
        var (ix, fx) = (x.exponent, x.significand)
        if fx < 1 { fx *= Self(Self.radix); ix -= 1 }
        let ir = ix == 0 ? Self(0) : Self(ix) * LN2(precision: px)
        var t = (fx - 1) / (fx + 1)
        let t2 = t * t
        var fr = t
        for i in 1...px {
            t *= t2
            t.truncate(width: px)
            fr += t / Self(2*i + 1)
            // print("POReal#log: i=\(i), t=~\(t.asDouble), r=~\(r.asDouble)")
            fr.truncate(width: px)
            if t < epsilon { break }
        }
        var r = ir + 2 * fr
        if 0 < px { r.truncate(width: px) }
        return r
    }
    /// common log (base 10)
    public static func log10(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        if x.isNaN          { return nan }
        if x.isLess(than:0) { return nan }
        if x.isZero         { return -infinity }
        if x.isInfinite     { return +infinity }
        var r =  log(x, precision:px) / LN10(precision:px * 2)
        if 0 < px { r.truncate(width: px) }
        return r
    }
    /// log(1 + x)
    public static func log1p(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        return log(1 + x, precision:px)
    }
    /// normalize `x` to ±π
    public static func normalizeAngle(_ x:Self, precision px:Int = Int64.bitWidth)->Self {
        var theta = x
        let onepi = PI(precision:px)
        if theta < -2*onepi || +2*onepi < theta {
            let precision = px + Int(theta.exponent)
            print("\(Self.self).wrapAngle: precision=", precision)
            let twopi = 2*PI(precision:precision)
            // print("before:", angle)
            theta = theta % twopi
            // print("after:", angle)
            theta.truncate(width:px)
        }
        if theta < -onepi { theta += 2*onepi }
        if +onepi < theta { theta -= 2*onepi }
        return theta
    }
    /// - returns: `(sin(x), cos(x))`
    public static func sincos(_ x:Self, precision px:Int = Int64.bitWidth, debug:Bool=false)->(sin:Self, cos:Self) {
        if x.isZero || x.isInfinite || x.isNaN {
            return (Self(Double.sin(x.asDouble)), Self(Double.cos(x.asDouble)))
        }
        let epsilon = Self(BigInt(1).over(1 << px.magnitude))
        if x * x <= epsilon {
            return (x, 1)   // sin(x) == x below this point
        }
        func inner(_ x:Self)->(Self, Self) {
            if 1 < Swift.abs(x) {
                var (s, c) = inner(x/2)     // use double-angle formula to reduce x
                if c == s { return (0, 1) } // prevent error accumulation
                (s, c) = (2*s*c, c*c - s*s)
                s.truncate(width:px*2)
                c.truncate(width:px*2)
                return (s, c)
            }
            var (c, s) = (Self(0), Self(0))
            var (n, d) = (Self(1), Self(1))
            for i in 0...px {
                let t = n / d
                if debug {
                    debugPrint("i:\(i) t.bitWidth:\(t.den.bitWidth)")
                }
                if i & 1 == 0 {
                    c += i & 2 == 2 ? -t : +t
                    c.truncate(width: px*2)
                } else {
                    s += i & 2 == 2 ? -t : +t
                    s.truncate(width: px*2)
                }
                if Swift.abs(t) < epsilon { break }
                n *= x
                n.truncate(width: px*2)
                d *= Self(i+1)
            }
            return (s, c)
        }
        var (s, c) = inner(Swift.abs(x) < 8 ? x : normalizeAngle(x))
        if 0 < px {
            s.truncate(width: px)
            c.truncate(width: px)
        }
        return (s, c)
    }
    /// cos(x)
    public static func cos(_ x:Self, precision px:Int = Int64.bitWidth, debug:Bool=false)->Self {
        return sincos(x, precision:px, debug:debug).cos
    }
    /// sin(x)
    public static func sin(_ x:Self, precision px:Int = Int64.bitWidth, debug:Bool=false)->Self {
        return sincos(x, precision:px, debug:debug).sin
    }
    /// tan(x)
    public static func tan(_ x:Self, precision px:Int = Int64.bitWidth, debug:Bool=false)->Self {
        if x.isZero || x.isInfinite || x.isNaN {
            return Self(Double.tan(x.asDouble))
        }
        let (s, c) = sincos(x, precision:px, debug:debug)
        if s.isNaN || s.isInfinite || c.isNaN || c.isInfinite {
            return Self(Double.tan(x.asDouble))
        }
        return s / c
    }
}

public protocol DoubleConvertible {
    var asDouble:Double { get }
}

extension Double: DoubleConvertible {}
extension Float:  DoubleConvertible {}

extension FloatingPoint where Self:DoubleConvertible {
    public var asBigRat : BigRat {
        return self as? BigRat ?? BigRat(self.asDouble)
    }
    public func toFloatingPointString(radix:Int = 10)->String {
        return self.asBigRat.toFloatingPointString(radix:radix)
    }
}
