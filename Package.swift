// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Telescope",
    products: [
        .library(
            name: "Telescope",
            targets: ["Telescope"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Lakr233/ScrubberKit.git", from: "0.1.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .target(
            name: "Telescope",
            dependencies: [
                .product(name: "ScrubberKit", package: "ScrubberKit"),
                .product(name: "MCP", package: "swift-sdk")
            ]
        ),
        .testTarget(
            name: "TelescopeTests",
            dependencies: ["Telescope"]
        ),
    ]
)
