// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MockingStarCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MockingStarCore",
            targets: ["MockingStarCore"]),
    ],
    dependencies: [
        .package(path: "../Server"),
        .package(path: "../CommonKit"),
        .package(path: "../PluginCore"),
    ],
    targets: [
        .target(
            name: "MockingStarCore",
            dependencies: [
                "Server",
                "CommonKit",
                "PluginCore"
            ]
        ),
        .testTarget(
            name: "MockingStarCoreTests",
            dependencies: [
                "MockingStarCore",
                .product(name: "CommonKitTestSupport", package: "CommonKit"),
            ]),
    ]
)
