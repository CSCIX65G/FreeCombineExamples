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
            targets: [
                "FreeCombine",
                "Channel",
                "Clock"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CSCIX65G/swift-atomics.git", branch: "CSCIX65G/playgrounds"),
        //        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.0.2")),
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.0.3")),
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics")
            ]
        ),
        .target(
            name: "Channel",
            dependencies: [
                "Core",
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "DequeModule", package: "swift-collections"),
            ]
        ),
        .target(
            name: "Clock",
            dependencies: [
                "FreeCombine",
                "Channel",
                .product(name: "Atomics", package: "swift-atomics")
            ]
        ),
        .target(
            name: "Future",
            dependencies: [
                "Core",
                .product(name: "Atomics", package: "swift-atomics"),
            ]
        ),
        .target(
            name: "Publisher",
            dependencies: [
                "Core",
                "Channel",
                "Future",
                .product(name: "Atomics", package: "swift-atomics"),
            ]
        ),
        .target(
            name: "FreeCombine",
            dependencies: [
                "Core",
                .product(name: "Atomics", package: "swift-atomics"),
            ]
        ),
        .testTarget(
            name: "FreeCombineTests",
            dependencies: [
                "Core",
                "FreeCombine",
                "Channel",
                "Clock"
            ]
        )
    ]
)
