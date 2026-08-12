// swift-tools-version: 6.3
//
// The same exercise as SwiftNumericsExample, against dankogai/swift-complex rather
// than apple/swift-numerics, and a package of its own for the same reason: SwiftPM
// resolves every declared dependency whether the target using it is being built or
// not, and swift-bignum's own manifest is meant to fetch nothing.
//
//     cd SwiftComplexExample && swift test
//
// swift-complex depends on swift-bignum itself, from 6.3.0.  The `path:".."` below
// declares the same package identity -- `swift-bignum`, taken from the directory
// name -- and a root path dependency wins, so both this package and swift-complex
// build against the checkout rather than a published tag.  That is the point of
// using a path here: the demo tests the working tree.
//
import PackageDescription

let package = Package(
    name: "SwiftComplexExample",
    products: [
        .library(
            name: "SwiftComplexExample",
            targets: ["SwiftComplexExample"]
        ),
    ],
    dependencies: [
      .package(url:"https://github.com/dankogai/swift-complex.git", branch:"main"),
      .package(path:".."),
    ],
    targets: [
        .target(
            name: "SwiftComplexExample",
            dependencies: [
                .product(name: "BigNum", package: "swift-bignum"),
                .product(name: "Complex", package: "swift-complex"),
            ]),
        .testTarget(
            name: "SwiftComplexExampleTests",
            dependencies: ["SwiftComplexExample"]),
    ],
     swiftLanguageModes: [.v6]
)
