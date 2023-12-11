// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PluginConfigs",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginConfigs",
            targets: ["PluginConfigs"]),
    ],
    dependencies: [
        .package(path: "../../Core/CommonViewsKit"),
        .package(path: "../../Core/PluginCore"),
        .package(url: "https://github.com/yusufozgul/AnyCodable", .upToNextMajor(from: "1.1.1")),
    ],
    targets: [
        .target(
            name: "PluginConfigs",
            dependencies: [
                "CommonViewsKit",
                "PluginCore",
                "AnyCodable",
            ]),
        .testTarget(
            name: "PluginConfigsTests",
            dependencies: [
                "PluginConfigs",
                .product(name: "CommonViewsKitTestSupport", package: "CommonViewsKit"),
                .product(name: "PluginCoreTestSupport", package: "PluginCore"),
            ]),
    ]
)
