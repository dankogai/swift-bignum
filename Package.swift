// swift-tools-version:4.0
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
        url: "https://github.com/dankogai/BigInt.git", .branch("master")
      )
    ],
    targets: [
        .target(
            name: "BigNum",
            dependencies: ["BigInt"]),
        .testTarget(
            name: "BigNumTests",
            dependencies: ["BigNum"]),
    ]
)
