// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PluginCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginCore",
            targets: ["PluginCore"]),
        .library(
            name: "PluginCoreLinux",
            targets: ["PluginCoreLinux"]),
        .library(
            name: "PluginCoreTestSupport",
            targets: ["PluginCoreTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/yusufozgul/SwiftyJS", .upToNextMinor(from: "0.0.4")),
        .package(url: "https://github.com/yusufozgul/AnyCodable", .upToNextMajor(from: "1.1.4")),
        .package(path: "../CommonKit"),
    ],
    targets: [
        .target(
            name: "PluginCore",
            dependencies: [
                "SwiftyJS",
                "AnyCodable",
                "CommonKit",
            ]),
        .target(name: "PluginCoreLinux",
                dependencies: [
                    "AnyCodable",
                    "CommonKit",
                ]),
        .target(name: "PluginCoreTestSupport", dependencies: [
            "PluginCore",
            "CommonKit",
        ]),
        .testTarget(
            name: "PluginCoreTests",
            dependencies: ["PluginCore",
                           .product(name: "CommonKitTestSupport", package: "CommonKit")
            ]),
    ]
)
