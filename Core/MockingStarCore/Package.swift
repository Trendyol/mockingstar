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
        .library(
            name: "MockingStarCoreTestSupport",
            targets: ["MockingStarCoreTestSupport"]),
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
                .product(name: "PluginCore", package: "PluginCore", condition: .when(platforms: [.macOS])),
                .product(name: "PluginCoreLinux", package: "PluginCore", condition: .when(platforms: [.linux])),
            ]
        ),
        .target(name: "MockingStarCoreTestSupport", dependencies: [
            "MockingStarCore"
        ]),
        .testTarget(
            name: "MockingStarCoreTests",
            dependencies: [
                "MockingStarCore",
                "MockingStarCoreTestSupport",
                .product(name: "CommonKitTestSupport", package: "CommonKit"),
            ]),
    ]
)
