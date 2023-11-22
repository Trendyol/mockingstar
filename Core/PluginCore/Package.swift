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
    ],
    dependencies: [
        .package(url: "https://github.com/yusufozgul/SwiftyJS", branch: "main"),
        .package(url: "https://github.com/theolampert/JSValueCoder", branch: "main"),
        .package(url: "https://github.com/yusufozgul/AnyCodable", .upToNextMajor(from: "1.1.1")),
        .package(path: "../CommonKit"),
    ],
    targets: [
        .target(
            name: "PluginCore",
            dependencies: [
                "SwiftyJS",
                "JSValueCoder",
                "AnyCodable",
                "CommonKit",
            ]),
        .testTarget(
            name: "PluginCoreTests",
            dependencies: ["PluginCore",
                           .product(name: "CommonKitTestSupport", package: "CommonKit")
                          ]),
    ]
)
