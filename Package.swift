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
        .package(url: "https://github.com/Lakr233/ScrubberKit.git", exact: "0.1.1"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", exact: "2.12.0")
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
            ],
            swiftSettings: [
                // Required for @main attribute in executables to avoid "top-level code" error
                // This tells Swift to treat main.swift as a library module when using @main
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "TelescopeTests",
            dependencies: ["Telescope"]
        ),
    ]
)
