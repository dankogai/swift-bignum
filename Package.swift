// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BigNum",
    products: [
        .library(
            name: "BigNum",
            targets: ["BigNum"]),
        // `**`, which is off unless you import it.  Swift has no submodules, so
        // an opt-in operator has to be an opt-in module.
        .library(
            name: "BigNumOperators",
            targets: ["BigNumOperators"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BigNum"),
        .target(
            name: "BigNumOperators",
            dependencies: ["BigNum"]),
        .target(
            name: "BigNumRun",
            dependencies: ["BigNum"]),
        .testTarget(
            name: "BigNumTests",
            dependencies: ["BigNum"]),
        .testTarget(
            name: "BigNumOperatorsTests",
            dependencies: ["BigNumOperators"]),
    ]
)
