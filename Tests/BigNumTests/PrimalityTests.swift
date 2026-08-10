import Testing
@testable import BigNum

///
/// The primality tests, against oracles that share nothing with them: a sieve of
/// Eratosthenes for the small numbers, published pseudoprime lists for the cases
/// built to defeat exactly these algorithms, and the known Mersenne exponents.
///
@Suite struct PrimalityTests {

    /// Plain Eratosthenes -- no modular exponentiation, no Lucas sequence, no
    /// idea in common with what it checks.
    static let limit = 20_000
    static let sieve:[Bool] = {
        var s = [Bool](repeating: true, count: limit)
        s[0] = false ; s[1] = false
        var i = 2
        while i * i < limit {
            if s[i] { var j = i * i ; while j < limit { s[j] = false ; j += i } }
            i += 1
        }
        return s
    }()
    static let primes:[Int] = (0 ..< limit).filter { sieve[$0] }

    @Test func againstTheSieve() {
        var wrong = 0
        for n in 0 ..< Self.limit {
            // every n here is far below 2^64, so a nil would itself be a bug --
            // comparing the Optional to a Bool catches that as well as a wrong answer
            if BigInt(n).isPrime  != Self.sieve[n] { wrong += 1 }
            if BigUInt(n).isPrime != Self.sieve[n] { wrong += 1 }
        }
        #expect(wrong == 0, "\(wrong) disagreements with the sieve below \(Self.limit)")
    }

    @Test func negativesAreNeverPrime() {
        for n in 1 ... 100 { #expect(BigInt(-n).isPrime == false, "-\(n) called prime") }
        #expect(BigInt(0).isPrime == false && BigInt(1).isPrime == false)
        #expect(BigUInt(0).isPrime == false && BigUInt(1).isPrime == false)
        #expect(BigInt(2).isPrime == true && BigInt(3).isPrime == true)
    }

    /// Strong pseudoprimes to base 2: composites that Miller-Rabin on base 2
    /// cannot see through, so only the Lucas half of BPSW rejects them.  Both
    /// halves are load-bearing and this is the list that proves it.
    @Test func strongPseudoprimesToBase2() {
        let spsp2 = [2047, 3277, 4033, 4681, 8321, 15841, 29341, 42799, 49141,
                     52633, 65281, 74665, 80581, 85489, 88357, 90751,
                     1373653, 25326001, 3215031751]
        for n in spsp2 {
            #expect(BigInt(n).millerRabinTest(base: 2),
                    "\(n) is a strong pseudoprime to base 2 and should pass that test")
            #expect(BigInt(n).isPrime == false, "\(n) is composite but isPrime said true")
        }
    }

    /// Carmichael numbers, which pass Fermat's test for every coprime base.
    @Test func carmichaelNumbers() {
        for n in [561, 1105, 1729, 2465, 2821, 6601, 8911, 10585, 15841, 29341,
                  41041, 46657, 52633, 62745, 63973, 75361] {
            #expect(BigInt(n).isPrime == false, "Carmichael \(n) called prime")
            #expect(BigInt(n).isSurelyPrime == (false, surely: true),
                    "a composite is always certain")
        }
    }

    /// Every entry of A014233 is composite by construction -- that is what makes
    /// it the boundary of what a set of Miller-Rabin bases can prove.
    @Test func a014233EntriesAreComposite() {
        for (i, entry) in BigInt.A014233.enumerated() {
            #expect(entry.isPrime == false, "A014233[\(i)] = \(entry) called prime")
            #expect(entry.isSurelyPrime == (false, surely: true), "A014233[\(i)]")
        }
        #expect(BigInt.A014233.count == BigInt._A014233Bases.count,
                "the table and its bases must stay in step")
        // it is sorted, which the isSurelyPrime loop relies on
        for i in 1 ..< BigInt.A014233.count {
            #expect(BigInt.A014233[i - 1] <= BigInt.A014233[i], "A014233 out of order at \(i)")
        }
    }

    /// Jacobi symbols against the recurrence written out directly in `Int`.
    func jacobiOracle(_ a:Int, _ n:Int) -> Int {
        if n <= 0 || n % 2 == 0 { return 0 }
        var (a, n, result) = (((a % n) + n) % n, n, 1)
        while a != 0 {
            while a % 2 == 0 {
                a /= 2
                if n % 8 == 3 || n % 8 == 5 { result = -result }
            }
            swap(&a, &n)
            if a % 4 == 3 && n % 4 == 3 { result = -result }
            a %= n
        }
        return n == 1 ? result : 0
    }

    @Test func jacobiSymbolAgainstOracle() {
        for n in [1, 3, 5, 7, 9, 15, 21, 45, 101, 1001, 9999, 104729] {
            for a in -60 ... 60 {
                #expect(BigInt(n).jacobiSymbol(a) == jacobiOracle(a, n),
                        "jacobi(\(a)/\(n))")
                #expect(BigUInt(n).jacobiSymbol(a) == jacobiOracle(a, n),
                        "unsigned jacobi(\(a)/\(n))")
            }
        }
        // an even or non-positive modulus has no symbol
        for n in [0, 2, 4, 8, 100] { #expect(BigInt(n).jacobiSymbol(3) == 0, "jacobi(3/\(n))") }
        for n in [-1, -3, -7] { #expect(BigInt(n).jacobiSymbol(3) == 0, "jacobi(3/\(n))") }
        // (a/1) is 1 for every a, including 0
        #expect(BigInt(1).jacobiSymbol(0) == 1 && BigInt(3).jacobiSymbol(0) == 0)
    }

    /// The Mersenne exponents are published, and Lucas-Lehmer is exact, so this
    /// is a straight lookup rather than a probable answer.
    @Test func lucasLehmerAgainstTheKnownMersennePrimes() {
        let primeExponents = [2, 3, 5, 7, 13, 17, 19, 31, 61, 89, 107, 127, 521, 607]
        for p in primeExponents {
            #expect((BigInt(1) << p - 1).isMersennePrime == true, "M\(p) is a Mersenne prime")
            #expect((BigUInt(1) << p - 1).isMersennePrime == true, "unsigned M\(p)")
            #expect((BigInt(1) << p - 1).isSurelyPrime == (true, surely: true),
                    "Lucas-Lehmer settles M\(p) outright")
        }
        // prime exponents whose Mersenne number is not prime
        for p in [11, 23, 29, 37, 41, 43, 47, 53, 59, 67, 71, 73, 79, 83, 97, 101, 103] {
            #expect((BigInt(1) << p - 1).isMersennePrime == false, "M\(p) is composite")
        }
        // a composite exponent always gives a composite Mersenne number
        for p in [4, 6, 8, 9, 10, 12, 15, 21, 25, 33, 49] {
            #expect((BigInt(1) << p - 1).isMersennePrime == false,
                    "M\(p) has a composite exponent")
        }
        // and anything that is not 2^p - 1 has no answer at all
        for n in [0, 1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 100, 1000, 1 << 20] {
            #expect(BigInt(n).isMersennePrime == nil, "\(n) is not a Mersenne number")
        }
        #expect(BigInt(-7).isMersennePrime == nil, "a negative is not a Mersenne number")
    }

    /// Miller-Rabin proves compositeness but never primality, so the only thing
    /// to pin per base is that it agrees with the sieve when it says "composite"
    /// and never contradicts a prime.
    @Test func millerRabinNeverRejectsAPrime() {
        for base in [BigInt(2), 3, 5, 7, 11, 13] {
            for n in Self.primes.prefix(400) where BigInt(n) > base {
                #expect(BigInt(n).millerRabinTest(base: base),
                        "\(n) is prime but base \(base) called it composite")
            }
        }
        #expect(!BigInt(1).millerRabinTest(base: 2))
        #expect(!BigInt(0).millerRabinTest(base: 2))
        #expect(BigInt(2).millerRabinTest(base: 2), "2 is even and prime")
        #expect(!BigInt(4).millerRabinTest(base: 2), "an even composite")
    }

    @Test func walkingThePrimes() {
        // nextPrime lands on the sieve's primes, in order
        var walked:[Int] = []
        var cursor = BigInt(0)
        while walked.count < 500 { cursor = cursor.nextPrime ; walked.append(Int(cursor)) }
        #expect(walked == Array(Self.primes.prefix(500)), "the nextPrime walk")
        // and so does the sequence
        #expect(BigInt.primes.prefix(500).map { Int($0) } == walked, "BigInt.primes")
        #expect(Array(BigUInt.primes.prefix(10)) == [2, 3, 5, 7, 11, 13, 17, 19, 23, 29])
        // both directions, against the sieve
        // every n here needs a prime on each side of it *within* the sieve, so
        // stay clear of its top end
        for n in [2, 3, 4, 5, 6, 100, 1000, 7919, 7920, 19000] {
            #expect(Int(BigInt(n).nextPrime) == Self.primes.first(where: { $0 > n })!,
                    "nextPrime of \(n)")
            let want = Self.primes.last(where: { $0 < n })
            #expect(BigInt(n).prevPrime.map { Int($0) } == want, "prevPrime of \(n)")
        }
        // the edges below 2, where there is no previous prime
        #expect(BigInt(0).prevPrime == nil && BigInt(1).prevPrime == nil)
        #expect(BigInt(2).prevPrime == nil && BigInt(-5).prevPrime == nil)
        #expect(BigUInt(2).prevPrime == nil && BigUInt(0).prevPrime == nil)
        #expect(BigInt(3).prevPrime == 2)
        #expect(BigInt(0).nextPrime == 2 && BigInt(-5).nextPrime == 2 && BigUInt(0).nextPrime == 2)
        // arbitrary precision means nextPrime can never run out of room, which is
        // why it is not an Optional -- there is nothing here to correspond to a
        // fixed-width type's overflow
        #expect((BigInt(1) << 64).nextPrime == BigInt("18446744073709551629")!)
    }

    /// Above A014233's last entry a prime is only probable; below it, and for any
    /// Mersenne number, the answer is certain.
    @Test func certaintyBoundary() {
        let beyond = BigInt(1) << 200
        #expect(beyond.isSurelyPrime == (false, surely: true), "a composite is always certain")
        // the first prime past 2^200, from the other side: BPSW says prime, but
        // it is above every deterministic bound this package has
        let p200 = (BigInt(1) << 200).nextPrime
        #expect(p200.isProbablePrime)
        #expect(p200.isPrime == nil, "BPSW says prime, but nothing here proves it")
        #expect(p200.isSurelyPrime == (true, surely: false),
                "past the table, a prime is only probable")
        // small primes stay certain
        for n in [2, 3, 5, 7, 97, 65537] {
            #expect(BigInt(n).isSurelyPrime == (true, surely: true), "\(n)")
        }
        // BPSW is exhaustively verified below 2^64, so that whole range is certain
        #expect(BigInt("18446744073709551557")!.isSurelyPrime == (true, surely: true),
                "the largest prime below 2^64 is certainly prime")
        #expect(BigInt(UInt64.max).isSurelyPrime == (false, surely: true))
    }

    /// `isPrime` has three answers, and the line between `true` and `nil` is
    /// exactly where a proof runs out.
    @Test func isPrimeWithholdsWhatItCannotProve() {
        #expect(BigInt(1000003).isPrime == true, "small primes are provable")
        #expect(BigInt(1000001).isPrime == false, "101 * 9901")
        // it is `isSurelyPrime` gated on its own second half, and nothing else
        for n in 0 ..< 300 {
            let (prime, surely) = BigInt(n).isSurelyPrime
            #expect(BigInt(n).isPrime == (surely ? prime : nil), "isPrime of \(n)")
        }
        // A composite is provable at any size: a witness is a proof.
        #expect((BigInt(1) << 1000).isPrime == false, "a huge even number")
        let m127 = BigInt(1) << 127 - 1
        let m89  = BigInt(1) << 89 - 1
        #expect((m127 * m89).isPrime == false, "a 216-bit product of two primes")
        // A Mersenne prime is provable at any size, because Lucas-Lehmer is exact
        #expect((BigInt(1) << 521 - 1).isPrime == true, "M521, far above 2^64")
        #expect((BigInt(1) << 523 - 1).isPrime == false, "M523")
        // The boundary itself: A014233's last entry is where thirteen
        // Miller-Rabin bases stop proving things.
        let table = BigInt.A014233
        let bound = table[table.count - 1]
        let below = bound.prevPrime!
        let above = bound.nextPrime
        #expect(below < bound && bound < above, "straddling the bound")
        #expect(below.isPrime == true, "\(below) is below the bound and provable")
        #expect(above.isPrime == nil, "\(above) is above it and is not")
        #expect(above.isProbablePrime, "though BPSW still says prime")
        #expect(below.isProbablePrime, "and agrees below the bound")
        // 2^64 is the other boundary, and it is covered by the table rather than
        // being the end of certainty
        #expect(BigInt("18446744073709551557")!.isPrime == true, "the last prime below 2^64")
        #expect((BigInt(1) << 64).nextPrime.isPrime == true, "just above 2^64, still provable")
        // The rename this change forced: `nextPrime` searches on
        // `isProbablePrime`, so it must still terminate where `isPrime` is nil.
        // Reading nil as "composite" would walk past every candidate forever.
        let floor200 = BigInt(1) << 200
        let high = floor200.nextPrime
        #expect(high > floor200, "nextPrime terminated above the deterministic range")
        #expect(high.isPrime == nil, "and its answer is withheld")
        #expect(high.isProbablePrime, "though BPSW still says prime")
    }

    /// The documented guarantee that makes `isPrime!` safe: at or below
    /// `UInt64.max` the answer is never withheld.  Every force unwrap here is the
    /// assertion -- it traps rather than fails if the guarantee ever breaks.
    @Test func isPrimeIsNeverNilThroughUInt64Max() {
        for n in 0 ..< 3000 {
            #expect(BigInt(n).isPrime != nil, "\(n)")
            #expect(BigUInt(n).isPrime != nil, "unsigned \(n)")
            #expect(BigInt(-n).isPrime! == false, "negatives are settled too: -\(n)")
        }
        // The boundary itself, and the values just inside it.  The window has to
        // reach 58 below the ceiling to contain a prime at all -- a narrower one
        // would be all composites, and a composite is settled by a witness no
        // matter what the certainty rules say, so it could not detect a prime
        // being withheld here.
        let ceiling = BigInt(UInt64.max)
        var primesFound = 0
        for offset in 0 ... 80 {
            let n = ceiling - BigInt(offset)
            #expect(n.isPrime != nil, "\(n) is at or below UInt64.max")
            #expect(BigUInt(n).isPrime != nil, "unsigned \(n)")
            if n.isPrime == true { primesFound += 1 }
        }
        #expect(primesFound > 0, "the window below the ceiling must contain a prime to be a test")
        #expect(ceiling.isPrime! == false, "UInt64.max == 3 * 5 * 17 * 257 * 641 * 65537 * 6700417")
        #expect(BigInt("18446744073709551557")!.isPrime! == true, "the last prime below 2^64")
        #expect(BigInt(Int.max).isPrime! == false, "Int.max == 7^2 * 73 * 127 * 337 * 92737 * 649657")
        #expect(BigInt(Int.min).isPrime! == false, "and anything negative")
        // powers of two and Mersenne-shaped values inside the range, which take
        // different routes through isSurelyPrime
        #expect((BigInt(1) << 1).isPrime! == true, "2^1 is 2, the one even prime")
        for p in 2 ... 63 {
            #expect((BigInt(1) << p).isPrime! == false, "2^\(p) is even and above 2")
            #expect((BigInt(1) << p - 1).isPrime != nil, "M\(p) is inside the range")
        }
        // just above the ceiling nothing is promised, but a composite is still settled
        #expect((ceiling + 1).isPrime! == false, "2^64 is even, so still provable")
    }

    /// A `BigInt` and a `BigUInt` of the same value must never disagree.
    @Test func signedAndUnsignedAgree() {
        for n in 0 ..< 1000 {
            #expect(BigInt(n).isPrime == BigUInt(n).isPrime, "isPrime of \(n)")
            #expect(BigInt(n).isSurelyPrime == BigUInt(n).isSurelyPrime, "isSurelyPrime of \(n)")
            #expect(BigInt(n).isLucasProbablePrime == BigUInt(n).isLucasProbablePrime,
                    "isLucasProbablePrime of \(n)")
        }
    }

    /// Large values, where the sieve cannot follow.  These are pinned by
    /// construction instead: a product of two primes is composite, and the primes
    /// themselves come out of `nextPrime` above a known power of two.
    @Test func largeValues() {
        let a = (BigInt(1) << 128).nextPrime
        let b = (BigInt(1) << 129).nextPrime
        // 128-bit primes are past every deterministic bound, so isPrime declines
        // to call them prime -- but their compositeness is still provable
        #expect(a.isPrime == nil && b.isPrime == nil, "unproven above the bound")
        #expect(a.isProbablePrime && b.isProbablePrime, "nextPrime returned a composite")
        #expect((a * b).isPrime == false, "the product of two primes is composite")
        #expect((a * b).isSurelyPrime == (false, surely: true))
        #expect((a * a).isPrime == false, "a square is composite")
        #expect(!(a * a).isLucasProbablePrime, "a perfect square fails the Lucas test outright")
        // a 256-bit prime.  Deliberately not wider: every candidate `nextPrime`
        // steps over costs a full BPSW test, and in a debug build a 512-bit
        // search alone ran longer than the rest of the suite put together.
        let big = (BigInt(1) << 256).nextPrime
        #expect(big.isProbablePrime)
        #expect(big.isPrime == nil, "a 256-bit prime is not provable here")
        #expect((big * 2).isPrime == false, "an even number above 2")
    }
}
