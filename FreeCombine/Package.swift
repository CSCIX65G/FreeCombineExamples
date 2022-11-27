// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "FreeCombine",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "FreeCombine",
            targets: ["FreeCombine"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CSCIX65G/swift-atomics.git", branch: "CSCIX65G/playgrounds"),
//        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.0.2")),
    ],
    targets: [
        .target(
            name: "FreeCombine",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics"),
            ]
        ),
        .testTarget(
            name: "FreeCombineTests",
            dependencies: ["FreeCombine"]
        ),
    ]
)
