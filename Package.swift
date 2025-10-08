// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Telescope",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "Telescope",
            targets: ["Telescope"]
        ),
        .executable(
            name: "telescope-server",
            targets: ["TelescopeServer"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Lakr233/ScrubberKit.git", from: "0.1.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0")
    ],
    targets: [
        .target(
            name: "Telescope",
            dependencies: [
                .product(name: "ScrubberKit", package: "ScrubberKit"),
                .product(name: "MCP", package: "swift-sdk")
            ]
        ),
        .executableTarget(
            name: "TelescopeServer",
            dependencies: [
                "Telescope",
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
            ]
        ),
        .testTarget(
            name: "TelescopeTests",
            dependencies: ["Telescope"]
        ),
    ]
)
