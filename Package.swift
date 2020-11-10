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
      .package(url: "https://github.com/apple/swift-numerics", from: "0.0.8"),
      .package(
        url: "https://github.com/attaswift/BigInt.git", from:"5.0.0"
      )
    ],
    targets: [
        .target(
            name: "BigNum",
            dependencies: [
              "BigInt",
              .product(name: "Numerics", package: "swift-numerics")
            ]),
        .target(
            name: "BigNumRun",
            dependencies: ["BigNum"]),
        .testTarget(
            name: "BigNumTests",
            dependencies: ["BigNum"]),
    ]
)
