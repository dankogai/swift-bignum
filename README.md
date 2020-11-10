[![Swift 5](https://img.shields.io/badge/swift-5-blue.svg)](https://swift.org)
[![MIT LiCENSE](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![build status](https://secure.travis-ci.org/dankogai/swift-bignum.png)](http://travis-ci.org/dankogai/swift-bignum)

# swift-bignum

Arbitrary-precision arithmetic for Swift, in Swift

## Synopsis

````swift
import BigNum
BigRat.sqrt(2, precision:128)  // 240615969168004511545033772477625056927/170141183460469231731687303715884105728
BigFloat.exp(1, precision:128) // 2.718281828459045235360287471352662497759
````

## Description

This module offers two flavors of Arbitrary-precision types that conforms to [FloatingPoint].

* `BigRat`   - Arbitrary-precision rational number.
* `BigFloat` - Arbitrary-precision floating point.

[FloatingPoint]: https://developer.apple.com/documentation/swift/floatingpoint

In addition to all arithmetic operations that [FloatingPoint] supports.  Most of the functions in `<math.h>` are offered as static functions.  As you see in the synopsis above, all arithmetic functions and operators that are lossy can take `precision:Int` as an optional argument.  When omitted the value of `BigRat.precision` or `BigFloat.precision` is used (default:64)

`BigInt`, an arbitrary-precision interger type is internally used and re-exported so you don't have to `import BigInt` just for that.  `BigInt` is also extended with `.over()` method so instead of constructing `BigRat` directly, you can:

```swift
BigInt(3260954456333195553).over(BigInt(2305843009213693952)) // == BigRat.sqrt(2)
```

## Usage

### build

```sh
$ git clone https://github.com/dankogai/swift-bignum.git
$ cd swift-complex # the following assumes your $PWD is here
$ swift build
```

### REPL

Simply

```sh
$ scripts/run-repl.sh
```

or

```sh
$ swift run --repl

```

and in your repl,

```sh
Welcome to Apple Swift version 4.2 (swiftlang-1000.11.37.1 clang-1000.11.45.1). Type :help for assistance.
  1> import BigNum 
  2> BigRat.sqrt(2, precision:128)
$R0: BigNum.BigRat = {
  num = {
    magnitude = {
      kind = array
      storage = 2 values {
        [0] = 6448461645324402335
        [1] = 13043817825332782212
      }
    }
    sign = plus
  }
  den = {
    magnitude = {
      kind = array
      storage = 2 values {
        [0] = 0
        [1] = 9223372036854775808
      }
    }
    sign = plus
  }
}
````

### Xcode

Xcode project is deliberately excluded from the repository because it should be generated via `swift package generate-xcodeproj` . For convenience, you can

```
$ scripts/xcode-prep
```

And the Workspace opens up for you with Playground on top.  The playground is written as a manual.


### From Your SwiftPM-Managed Projects

Add the following to the `dependencies` section:

```swift
.package(
  url: "https://github.com/dankogai/swift-bignum.git", .branch("main")
)
```

and the following to the `.target` argument:

```swift
.target(
  name: "YourSwiftyPackage",
  dependencies: ["BigNum"])
```

Now all you have to do is:

```swift
import BigNum
```

in your code.  Enjoy!

# Prerequisite

Swift 5 or better, OS X or Linux to build.

Depends on [attaswift/BigInt] for internal representation of `BigFloat` and `BigRat`.

[attaswift/BigInt]: https://github.com/attaswift/BigInt
[apple/swift-numerics]: https://github.com/apple/swift-numerics
[dankogai/swift-floatingpoint]: https://github.com/danogai/swift-floatingpoint

Depends on [apple/swift-numerics] since version 5.1 for the `ElementaryFunctions` protocol.  Prior versions depended on [dankogai/swift-floatingpoint] for the `FloatingPointMath` protocols but it is replaced by the `ElementaryFunctions`.
