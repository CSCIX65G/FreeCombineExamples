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
                "Clock",
                "Future",
                "Publisher",
                "Queue"
            ]
        ),
    ],
    dependencies: [
//        .package(url: "https://github.com/CSCIX65G/swift-atomics.git", branch: "CSCIX65G/playgrounds"),
        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.0.2")),
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
                "Channel",
                "Future",
                "Queue",
                .product(name: "Atomics", package: "swift-atomics")
            ]
        ),
        .target(
            name: "Future",
            dependencies: [
                "Core",
                "Queue",
                .product(name: "Atomics", package: "swift-atomics"),
            ]
        ),
        .target(
            name: "Publisher",
            dependencies: [
                "Core",
                "Channel",
                "Future",
                "Queue",
                .product(name: "Atomics", package: "swift-atomics"),
            ]
        ),
        .target(
            name: "Queue",
            dependencies: [
                "Core",
                "Channel",
                .product(name: "Atomics", package: "swift-atomics"),
            ]
        ),
        .target(
            name: "FreeCombine",
            dependencies: [
                "Core",
                "Channel",
                "Future",
                "Publisher",
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
