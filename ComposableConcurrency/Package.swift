// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "ComposableConcurrency",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "ComposableConcurrency",
            targets: [
                "ComposableConcurrency",
                "Channel",
                "Clock",
                "Future",
                "Publisher",
                "Queue"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CSCIX65G/swift-atomics.git", branch: "CSCIX65G/playgrounds"),
//        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.0.3")),
        .package(url: "https://github.com/apple/swift-collections.git", branch: "release/1.1"),
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
                .product(name: "HashTreeCollections", package: "swift-collections"),
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
            name: "ComposableConcurrency",
            dependencies: [
                "Core",
                "Channel",
                "Clock",
                "Future",
                "Publisher",
                .product(name: "Atomics", package: "swift-atomics"),
            ]
        ),
        .testTarget(
            name: "ComposableConcurrencyTests",
            dependencies: [
                "ComposableConcurrency"
            ]
        )
    ]
)
