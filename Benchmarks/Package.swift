// swift-tools-version:5.9
//
// A package of its own, deliberately.  swift-bignum's own manifest has no
// dependencies and `swift build` at the root fetches nothing -- that is a
// property worth keeping, and a benchmark target in the root manifest would
// quietly end it, since SwiftPM resolves every declared dependency whether the
// target using it is being built or not.
//
// So: run the benchmark by asking for it.
//
//     cd Benchmarks && swift run -c release
//
import PackageDescription

let package = Package(
    name: "BigNumBenchmark",
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.7.0"),
    ],
    targets: [
        // See Sources/Attaswift: both libraries want the name `BigInt`, and only
        // a benchmark ever needs them in the same file.
        .target(
            name: "Attaswift",
            dependencies: [.product(name: "BigInt", package: "BigInt")]),
        .executableTarget(
            name: "BigNumBenchmark",
            dependencies: [
                .product(name: "BigNum", package: "swift-bignum"),
                "Attaswift",
            ]),
    ]
)
