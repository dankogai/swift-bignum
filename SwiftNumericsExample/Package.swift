// swift-tools-version: 6.3
//
// A demo of using BigNum alongside apple/swift-numerics, and a package of its own
// so that swift-bignum's root manifest keeps its no-dependencies property -- see
// Benchmarks/Package.swift, which is separate for the same reason.
//
//     cd SwiftNumericsExample && swift test
//
// The parent is a `path:` dependency, not a `url:` one.  A URL pointing at `..`
// makes SwiftPM clone the parent as a git working copy and resolve it to a
// *committed* revision, so uncommitted work in the checkout you are sitting in is
// invisible to the demo.  `path:` reads the directory itself, which is what a
// sibling demo wants.
//
// Its package identity is `swift-bignum`, from the directory name rather than from
// the `name: "BigNum"` in its manifest -- that is what `.product(package:)` below
// has to match.
//
import PackageDescription

let package = Package(
    name: "SwiftNumericsExample",
    products: [
        .library(
            name: "SwiftNumericsExample",
            targets: ["SwiftNumericsExample"]
        ),
    ],
    dependencies: [
      .package(url:"https://github.com/apple/swift-numerics", from:"1.0.0"),
      .package(path:".."),
    ],
    targets: [
        // Products from another package need `.product(name:package:)`; a bare
        // string names a target in *this* package, which is why "BigNum" alone
        // came back as "product 'BigNum' ... not found".
        .target(
            name: "SwiftNumericsExample",
            dependencies: [
                .product(name: "BigNum", package: "swift-bignum"),
                .product(name: "RealModule", package: "swift-numerics"),
                .product(name: "ComplexModule", package: "swift-numerics"),
            ]),
        .testTarget(
            name: "SwiftNumericsExampleTests",
            dependencies: ["SwiftNumericsExample"]),
    ],
     swiftLanguageModes: [.v6]
)
