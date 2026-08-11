# Caveat

Up to version 5.x this package got `BigInt` and `BigUInt` from
[attaswift/BigInt]. It now has its own, and they are **not** a drop-in
replacement. Most code moves across untouched; this is the list of what does not,
so you can find out by reading rather than by compiling.

Nothing here is a plan. These are differences, some of them deliberate, and the
document exists because "mostly compatible" is not a useful thing to be told.

## How this was measured

Every public member attaswift/BigInt declares was written out as a use of *our*
`BigInt`/`BigUInt` — 106 usages in all — and handed to the compiler. **50 compile
and 56 do not.** What follows is the 56, grouped by what it would take to close
them, plus the two behavioural differences that compile fine and then do
something else.

The count is of usages, not of features: several members appear twice because
attaswift declares them on both types.

## Behaviour: compiles, differs

These are the dangerous ones, because nothing tells you.

### `>>` on a negative value

| value | `Int` | swift-bignum | attaswift |
|---:|---:|---:|---:|
| -3 | -2 | -2 | **-1** |
| -5 | -3 | -3 | **-2** |
| -1025 | -513 | -513 | **-512** |

`BinaryInteger` specifies an arithmetic shift, which floors. That is what `Int`
does, what this package does, and what JavaScript, Python and Ruby do.
attaswift shifts the magnitude and keeps the sign, which truncates toward zero.
Across the seven values in [Benchmark.md](Benchmark.md), we match `Int` 7 times
and attaswift 3.

**If your code right-shifts negative numbers, the answers will change** — to the
ones `Int` would have given.

### `Codable`

A `BigInt` encodes as a single base-16 string; attaswift encodes sign and words.
Archives written by 5.x will not decode. Readable in a JSON dump was worth more
than compatibility with a format nothing else reads, but if you have stored data,
that is a migration and not a recompile.

### Thread safety

`BigRat` and `BigFloat` memoise π/4, e, √2, ln 2 and ln 10 per precision in
`static var`s, and their `precision`, `roundingRule` and `expLimit` are settable
statics too. **None of it is synchronised.** Two threads asking for a
transcendental at the same time can read and write one of those memos at once,
and because the stored value owns a reference-counted array, the failure mode is
not a wrong answer but a corrupted heap.

It is intermittent and it does happen: one Linux CI run of this very pull request
aborted with `SIGABRT` and passed on re-run, and the thread sanitiser, given a
concurrent stress test, names the race — `static BigRational.E.setter`. It
reproduces perhaps one run in ten, which is why it went unnoticed.

Scope, which is narrower than it sounds:

* **`BigInt` and `BigUInt` are unaffected.** They have no mutable static state at
  all — checked file by file — so integer code is as safe concurrently as any
  other value type.
* **`BigRat` and `BigFloat` arithmetic** (`+`, `*`, `/`, comparison, conversion)
  is also unaffected. Only the transcendental functions and `precision` touch the
  shared statics.
* So the exposure is concurrent calls to `exp`, `log`, `pow`, `sqrt`, the
  trigonometrics, `pi`, or assignment to `precision`.

Until it is fixed, confine those to one thread or serialise around them.

**attaswift has no mutable static state anywhere**, so this is a way code that was
thread-safe against it can stop being thread-safe here. Both libraries declare
their types `Sendable`; ours is telling the truth about the values and not about
the constants beside them.

This is a defect rather than a design difference, and unlike everything else in
this document it should be fixed rather than documented. It is written down here
because it was found while checking the rest, and because a known crash deserves
to be findable before it is fixed.

## Missing: the same capability under another name

Eleven members — 22 of the 56 usages — all of which we can already do. Nothing is stopping these from
being added; they are not, because each one is a name we would have to keep.

| attaswift | here | difference |
|---|---|---|
| `power(_:modulus:)` | `power(_:mod:)` | the argument label |
| `isStrongProbablePrime(_:)` | `millerRabinTest(base:)` | the name |
| `inverse(_:) -> Self?` | `power(-1, mod:)` | **ours traps where attaswift returns nil.** The `nil` case is computed internally and not exposed |
| `isPrime(rounds:) -> Bool` | `isPrime: Bool?` | a method taking a round count, against a property that returns `nil` when it cannot prove the answer. See [BigInt.md](BigInt.md#primality) |
| `modulus(_:)` | `((x % m) + m) % m` | Euclidean modulus, always non-negative; ours is truncating, so it takes the dividend's sign. That replacement is checked against attaswift over 3000 values |
| `debugDescription` | `description` | not `CustomDebugStringConvertible` |
| `playgroundDescription` | — | not `CustomPlaygroundDisplayConvertible` |
| `&<<`, `&>>` | `<<`, `>>` | masking shifts, which at arbitrary precision are the plain ones — there is no width to mask against |
| `init(words:)` | `init(_:)` from any `BinaryInteger` | no construction from a word sequence |
| `let x: BigInt = "123"` | `BigInt("123")!` | not `ExpressibleByStringLiteral`. The literal form traps on nonsense; the initializer returns nil |
| `leadingZeroBitCount` | — | attaswift counts within its word storage. For an unbounded value there is no width to count from, so it would have to mean "within `bitWidth`" and that is a different question than the one `FixedWidthInteger` answers |

## Missing: capability we do not have

### Random values — 6 usages

```swift
BigUInt.randomInteger(withMaximumWidth: 1024)
BigUInt.randomInteger(withExactWidth: 1024)
BigUInt.randomInteger(lessThan: n)
// and each with `using: &generator`
```

There is no equivalent. Build one from `SystemRandomNumberGenerator` and
`init(words:)`… which is also missing, so from `<<` and `|` over `UInt.random(in:)`.

### Byte serialization — 10 usages

```swift
u.serialize() -> Data
BigUInt(data)
u.serializeToBuffer() -> UnsafeRawBufferPointer
BigUInt(someRawBufferPointer)
BigInt(exactly: someDecimal)
BigInt(truncating: someDecimal)
```

Big-endian bytes, in both directions, on both types — four member names, so eight
usages — plus the two `Decimal` initializers. All of it needs Foundation, and `Sources/BigNum` imports Foundation
nowhere — the whole package is the standard library and the platform's libm. That
is the reason, and it is a real cost: there is no supported way to get a `BigInt`
in or out as bytes. `toString(radix: 16)` and `init?(_:radix:)` round-trip
losslessly and are fast, but they are text.

## Missing: API that publishes a representation

Eighteen usages, and the ones least likely to change. attaswift is
sign-and-magnitude over an array of words, and says so in its API. This package
is two's complement over `[UInt]` limbs, and does not.

### The sign

```swift
x.sign              // BigInt.Sign, .plus or .minus
BigInt.Sign.self
BigInt(sign: .minus, magnitude: BigUInt(5))
```

A two's-complement value has no separate sign to return. Use `isNegative`,
`signum()`, `magnitude`, or `< 0` — and note that a sign-and-magnitude type has to
legislate away negative zero, while this one cannot represent it.

### The words

```swift
u[0]                // subscript(Int) -> Word
u[bitAt: 3]         // subscript(bitAt:) -> Bool
u.count             // how many words
BigUInt.Word        // the word type
```

`words` is there, and **the two libraries agree on it, negatives included** —
`BinaryInteger` specifies two's complement, so attaswift synthesizes from its sign
and magnitude what this package stores directly. Checked over 2500 values. Code
reading `words` ports unchanged.

What is not there is indexed access, bit access, a word count, or a public name for
the word type. Exposing them would fix the storage in place, and `words` plus
`bitWidth` answer most of what they were for.

### The word-level operations — 9 members, 10 usages

```swift
u.multiplied(by: v)                        // and multiplied(byWord:)
u.multiply(byWord: w)
u.multiplyAndAdd(v, w, shiftedBy: k)
u.subtracting(v)                           // and subtracting(_:shiftedBy:)
u.subtract(v, shiftedBy: k)
u.subtractingReportingOverflow(v)
u.subtractReportingOverflow(v, shiftedBy: k)
u.decrement(shiftedBy: k)
```

attaswift's internals, made public: in-place mutation, a shift built into the
operand, and overflow reporting on a type that cannot overflow. The equivalents
here are `*`, `-`, `<<` and the compound assignments.

**`shiftedBy` counts words, not bits**, so the shifted forms translate as
`x - (y << (k * UInt.bitWidth))` — the obvious reading of `y << k` is wrong by a
factor of 64. Checked against attaswift over 2000 cases, as is `multiplied(by:)`
being `*`.

`subtractingReportingOverflow` has no counterpart, and this one is a real hole
rather than a rename. Subtracting past zero traps here, as it does for `UInt`.
attaswift instead **reports**: `BigUInt(3).subtractingReportingOverflow(BigUInt(10))`
returns `(18446744073709551609, true)` — wrapped into one word, with the flag set,
and no trap. Code relying on that flag has to become a `>=` test before the
subtraction; there is nothing here that returns instead of trapping.

## What does move across

For balance, since the list above is longer than it feels: all 50 of these
compile unchanged.

* Every arithmetic, comparison, bitwise and shift operator, and their compound
  forms
* `quotientAndRemainder(dividingBy:)`, `isMultiple(of:)`, `negate()`, `signum()`,
  `magnitude`, `isZero`, `isSigned`
* `power(_:)` with an `Int` exponent, `squareRoot()`,
  `greatestCommonDivisor(with:)`
* `words`, `Words`, `Magnitude`, `bitWidth`, `trailingZeroBitCount`
* `Codable` (the protocol; see the format caveat above), `Hashable`, `Comparable`
* The whole `Strideable` surface, including `advanced(by:)`, `distance(to:)`,
  `Stride`, and `stride(from:to:by:)`
* `String(_:radix:uppercase:)` and `init?(_:radix:)`
* Every `BinaryInteger` conversion — plain, `exactly:`, `clamping:`,
  `truncatingIfNeeded:` — and both `BinaryFloatingPoint` directions

And a good deal that attaswift has no answer for: `isPrime`/`isSurelyPrime` and
the primality family, `power(_:mod:)` with an exponent as wide as the modulus,
`over(_:)`, the rational and floating-point types, and all of it on the built-in
integers as well. See the [README](README.md).

[attaswift/BigInt]: https://github.com/attaswift/BigInt
