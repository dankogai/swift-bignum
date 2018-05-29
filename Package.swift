// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BigNum",
    products: [
        .library(
            name: "BigNum",
            type: .dynamic,
            targets: ["BigNum"]),
    ],
    dependencies: [
      .package(
        url: "https://github.com/dankogai/swift-floatingpointmath.git", .branch("master")
      ),
      .package(
        url: "https://github.com/dankogai/BigInt.git", .branch("master")
      )
    ],
    targets: [
        .target(
            name: "BigNum",
            dependencies: ["BigInt", "FloatingPointMath"]),
        .target(
            name: "BigNumRun",
            dependencies: ["BigNum"]),
        .testTarget(
            name: "BigNumTests",
            dependencies: ["BigNum"]),
    ]
)
