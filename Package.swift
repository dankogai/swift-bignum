// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BigNum",
    products: [
        .library(
            name: "BigNum",
            targets: ["BigNum"]),
    ],
    dependencies: [
      .package(
        url: "https://github.com/apple/swift-numerics", from: "1.0.0"
      ),
      .package(
        url: "https://github.com/attaswift/BigInt", from: "5.0.0"
      )
    ],
    targets: [
        .target(
            name: "BigNum",
            dependencies: [
                .product(name: "BigInt", package: "BigInt"),
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
