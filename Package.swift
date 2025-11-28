// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "QueuesValkeyDriver",
    platforms: [
        .macOS(.v15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "QueuesValkeyDriver",
            targets: ["QueuesValkeyDriver"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/valkey-io/valkey-swift.git", "0.4.0" ..< "0.5.0"),
        .package(url: "https://github.com/vapor/queues.git", from: "1.12.1"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.100.0"),
        .package(url: "https://github.com/vapor-community/valkey.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "QueuesValkeyDriver",
            dependencies: [
                .product(name: "Queues", package: "queues"),
                .product(name: "Valkey", package: "valkey-swift"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "VaporValkey", package: "valkey"),
            ]
        ),
        .testTarget(
            name: "QueuesValkeyDriverTests",
            dependencies: [
                "QueuesValkeyDriver",
                .product(name: "VaporTesting", package: "vapor"),
            ]
        ),
    ]
)
