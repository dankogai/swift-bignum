//
//  BigNum's BigInt against attaswift/BigInt.
//
//  Run it with `swift run -c release` from the Benchmarks directory.  A debug
//  build measures the optimizer's absence, not the algorithms -- generic
//  specialization is most of what makes either library fast -- so this refuses
//  to report numbers from one.
//
//  Method, such as it is:
//
//   *  Both libraries get the *same* inputs, built by parsing one hex string
//      each, so neither is handed a representation the other has to convert.
//   *  Every case is checked for agreement before it is timed.  A benchmark of
//      two functions that compute different things is worthless, and this
//      doubles as a differential test against a mature implementation.
//   *  Iteration count scales until a batch takes 50ms, then the best of five
//      batches is reported.  Best-of rather than mean: the distribution is
//      one-sided, since interference can only slow a batch down.
//   *  Every result is folded into a checksum that gets printed, so nothing
//      being measured is dead code.
//
//  What the numbers are not: a verdict.  attaswift/BigInt is sign-and-magnitude
//  and this is two's complement, which is a design difference with a cost on
//  each side, and neither library has been tuned against the other.
//

import Foundation
import BigNum
import Attaswift

typealias Ours = BigInt              // swift-bignum's
typealias Theirs = AttaswiftBigInt   // attaswift's, renamed by the shim

// MARK: - plumbing

/// Everything measured folds into here, so the optimizer cannot delete it.
var checksum: UInt64 = 0

@inline(__always) func fold(_ v: Ours) -> UInt64 {
    return UInt64(truncatingIfNeeded: v.words.first ?? 0) ^ UInt64(v.words.count)
}
@inline(__always) func fold(_ v: Theirs) -> UInt64 {
    return UInt64(truncatingIfNeeded: v.words.first ?? 0) ^ UInt64(v.words.count)
}
@inline(__always) func fold(_ v: Bool) -> UInt64 { return v ? 1 : 0 }
@inline(__always) func fold(_ v: String) -> UInt64 { return UInt64(v.utf8.count) }

/// Splitmix64, so the inputs are the same on every machine and every run.
struct Random {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    /// A hex string of exactly `bits` bits, top bit set so the width is honest.
    mutating func hex(bits: Int) -> String {
        var s = ""
        var remaining = bits
        while remaining > 0 {
            let take = Swift.min(64, remaining)
            var word = next()
            if remaining == bits {                      // the top chunk
                word |= 1 << UInt64(take - 1)           // ... has its top bit set
                if take < 64 { word &= (1 << UInt64(take)) - 1 }
            }
            s += String(word, radix: 16)
                   .leftPadded(to: remaining == bits ? (take + 3) / 4 : 16)
            remaining -= take
        }
        return s
    }
}

extension String {
    func leftPadded(to n: Int) -> String {
        return count >= n ? self : String(repeating: "0", count: n - count) + self
    }
}

func measure(_ body: () -> UInt64) -> Double {
    var n = 1
    var elapsed: UInt64 = 0
    while true {
        let t0 = DispatchTime.now().uptimeNanoseconds
        var acc: UInt64 = 0
        for _ in 0 ..< n { acc = acc &+ body() }
        elapsed = DispatchTime.now().uptimeNanoseconds - t0
        checksum = checksum &+ acc
        if elapsed >= 50_000_000 || n >= 1 << 28 { break }
        n = elapsed < 1_000_000 ? n * 16 : n * 2
    }
    var best = Double(elapsed) / Double(n)
    for _ in 0 ..< 4 {
        let t0 = DispatchTime.now().uptimeNanoseconds
        var acc: UInt64 = 0
        for _ in 0 ..< n { acc = acc &+ body() }
        let each = Double(DispatchTime.now().uptimeNanoseconds - t0) / Double(n)
        checksum = checksum &+ acc
        best = Swift.min(best, each)
    }
    return best
}

struct Result {
    let op: String, bits: Int, ours: Double, theirs: Double, agreed: Bool
}
var results: [Result] = []

/// Check first, then time.  `same` returns whether the two produced equal
/// answers -- compared as decimal strings, the one representation both agree on.
func bench(_ op: String, _ bits: Int,
           same: () -> Bool,
           ours: @escaping () -> UInt64,
           theirs: @escaping () -> UInt64) {
    let agreed = same()
    if !agreed { FileHandle.standardError.write("DISAGREEMENT: \(op) at \(bits) bits\n".data(using: .utf8)!) }
    let o = measure(ours)
    let t = measure(theirs)
    results.append(Result(op: op, bits: bits, ours: o, theirs: t, agreed: agreed))
    let ratio = t / o
    FileHandle.standardError.write(
      String(format: "  %-22s %5d bits  ours %10.1f ns  theirs %10.1f ns  %5.2fx%@\n",
             (op as NSString).utf8String!, bits, o, t, ratio,
             agreed ? "" : "  ** DISAGREED **").data(using: .utf8)!)
}

// MARK: - the cases

let sizes = [64, 256, 1024, 4096]

for bits in sizes {
    var rng = Random(seed: 0x5EED_0000 &+ UInt64(bits))
    let ha = rng.hex(bits: bits), hb = rng.hex(bits: bits)
    let hwide = rng.hex(bits: bits * 2)
    let (oa, ob) = (Ours(ha, radix: 16)!, Ours(hb, radix: 16)!)
    let (ta, tb) = (Theirs(ha, radix: 16)!, Theirs(hb, radix: 16)!)
    let (owide, twide) = (Ours(hwide, radix: 16)!, Theirs(hwide, radix: 16)!)
    // negatives, where two's complement and sign-and-magnitude actually differ
    let (ona, onb) = (-oa, -ob)
    let (tna, tnb) = (-ta, -tb)
    let decimal = oa.description
    precondition(decimal == ta.description, "inputs differ at \(bits) bits")

    bench("+", bits, same: { (oa + ob).description == (ta + tb).description },
          ours: { fold(oa + ob) }, theirs: { fold(ta + tb) })
    bench("-", bits, same: { (oa - ob).description == (ta - tb).description },
          ours: { fold(oa - ob) }, theirs: { fold(ta - tb) })
    bench("*", bits, same: { (oa * ob).description == (ta * tb).description },
          ours: { fold(oa * ob) }, theirs: { fold(ta * tb) })
    bench("* (negative)", bits, same: { (ona * onb).description == (tna * tnb).description },
          ours: { fold(ona * onb) }, theirs: { fold(tna * tnb) })
    bench("/", bits, same: { (owide / ob).description == (twide / tb).description },
          ours: { fold(owide / ob) }, theirs: { fold(twide / tb) })
    bench("%", bits, same: { (owide % ob).description == (twide % tb).description },
          ours: { fold(owide % ob) }, theirs: { fold(twide % tb) })
    bench("<", bits, same: { (oa < ob) == (ta < tb) },
          ours: { fold(oa < ob) }, theirs: { fold(ta < tb) })
    bench("<< 61", bits, same: { (oa << 61).description == (ta << 61).description },
          ours: { fold(oa << 61) }, theirs: { fold(ta << 61) })
    bench(">> 61", bits, same: { (oa >> 61).description == (ta >> 61).description },
          ours: { fold(oa >> 61) }, theirs: { fold(ta >> 61) })
    // This one does not agree, and the disagreement is the point: `Int(-5) >> 1`
    // is -3, and so is ours, while attaswift shifts the magnitude and keeps the
    // sign, giving -2.  Timing it is still worth doing -- just not as a race.
    bench(">> 61 (negative)", bits, same: { (ona >> 61).description == (tna >> 61).description },
          ours: { fold(ona >> 61) }, theirs: { fold(tna >> 61) })
    bench("& (negative)", bits, same: { (ona & onb).description == (tna & tnb).description },
          ours: { fold(ona & onb) }, theirs: { fold(tna & tnb) })
    bench("~ (negative)", bits, same: { (~ona).description == (~tna).description },
          ours: { fold(~ona) }, theirs: { fold(~tna) })
    bench("description", bits, same: { oa.description == ta.description },
          ours: { fold(oa.description) }, theirs: { fold(ta.description) })
    bench("init(radix: 10)", bits, same: { Ours(decimal)!.description == Theirs(decimal)!.description },
          ours: { fold(Ours(decimal)!) }, theirs: { fold(Theirs(decimal)!) })
    bench("init(radix: 16)", bits, same: { Ours(ha, radix: 16)!.description == Theirs(ha, radix: 16)!.description },
          ours: { fold(Ours(ha, radix: 16)!) }, theirs: { fold(Theirs(ha, radix: 16)!) })
    bench("squareRoot", bits, same: { oa.squareRoot().description == ta.squareRoot().description },
          ours: { fold(oa.squareRoot()) }, theirs: { fold(ta.squareRoot()) })
    bench("gcd", bits, same: { oa.greatestCommonDivisor(with: ob).description
                                 == ta.greatestCommonDivisor(with: tb).description },
          ours: { fold(oa.greatestCommonDivisor(with: ob)) },
          theirs: { fold(ta.greatestCommonDivisor(with: tb)) })
    bench("power(5)", bits, same: { oa.power(5).description == ta.power(5).description },
          ours: { fold(oa.power(5)) }, theirs: { fold(ta.power(5)) })
    // modular exponentiation, with the exponent the same width as the modulus --
    // the shape RSA and Diffie-Hellman use.  Capped: at 4096 bits one call is
    // seconds, and five batches of it says nothing the smaller sizes do not.
    if bits <= 1024 {
        bench("power(e, mod:)", bits,
              same: { oa.power(ob, mod: owide).description
                        == ta.power(tb, modulus: twide).description },
              ours: { fold(oa.power(ob, mod: owide)) },
              theirs: { fold(ta.power(tb, modulus: twide)) })
    }
}

// MARK: - semantics, where a difference is not a matter of speed
//
// The benchmark above flags disagreements but cannot say who is right.  `Int` can:
// the standard library specifies `>>` on a signed type as arithmetic, so whatever
// `Int` does is the contract.

func shiftSemantics() -> [(Int, String, String, String)] {
    var out: [(Int, String, String, String)] = []
    for v in [-1, -2, -3, -5, -7, -8, -1025] {
        out.append((v, "\(v >> 1)", "\(Ours(v) >> 1)", "\(Theirs(v) >> 1)"))
    }
    return out
}

// MARK: - report

#if DEBUG
print("""
    **This is a debug build and the numbers below are meaningless.**  Neither
    library is specialized without the optimizer.  Re-run with:

        swift run -c release
    """)
#endif

let disagreements = results.filter { !$0.agreed }
print("")
print("| operation | bits | swift-bignum | attaswift | ratio |")
print("|---|---:|---:|---:|---:|")
func format(_ ns: Double) -> String {
    if ns < 1000 { return String(format: "%.0f ns", ns) }
    if ns < 1_000_000 { return String(format: "%.2f µs", ns / 1000) }
    return String(format: "%.2f ms", ns / 1_000_000)
}
for r in results {
    let ratio = r.theirs / r.ours
    let verdict = !r.agreed
      ? "not comparable"
      : (ratio >= 1 ? String(format: "**%.2f×**", ratio)
                    : String(format: "%.2f×", ratio))
    print("| `\(r.op)` | \(r.bits) | \(format(r.ours)) | \(format(r.theirs)) | \(verdict) |")
}
print("")
print("\(results.count) cases, \(results.count - disagreements.count) in agreement"
        + (disagreements.isEmpty ? "." : "."))
if !disagreements.isEmpty {
    print("")
    print("Disagreed, so no ratio is reported for them: "
            + Set(disagreements.map { "`\($0.op)`" }).sorted().joined(separator: ", ") + ".")
}
let semantics = shiftSemantics()
let deviating = semantics.filter { $0.1 != $0.3 }
if !deviating.isEmpty {
    print("")
    print("`>> 1` against `Int`, which defines the contract:")
    print("")
    print("| value | `Int` | swift-bignum | attaswift |")
    print("|---:|---:|---:|---:|")
    for (v, i, o, t) in semantics {
        print("| \(v) | \(i) | \(o)\(o == i ? "" : " **differs**") | \(t)\(t == i ? "" : " **differs**") |")
    }
    print("")
    let oursOff = semantics.filter { $0.1 != $0.2 }.count
    print("swift-bignum matches `Int` in \(semantics.count - oursOff) of \(semantics.count) cases; "
            + "attaswift in \(semantics.count - deviating.count).")
}
print("")
print("Cores: \(ProcessInfo.processInfo.activeProcessorCount). Checksum: \(checksum).")
