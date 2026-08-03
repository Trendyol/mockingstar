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
            name: "PluginCoreTestSupport",
            targets: ["PluginCoreTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/yusufozgul/AnyCodable", .upToNextMajor(from: "1.1.4")),
        .package(path: "../CommonKit"),
    ],
    targets: [
        .target(
            name: "QuickJSCore",
            path: "Vendor/QuickJS",
            sources: [
                "quickjs.c",
                "cutils.c",
                "dtoa.c",
                "libregexp.c",
                "libunicode.c",
            ],
            publicHeadersPath: ".",
            cSettings: [
                .define("CONFIG_VERSION", to: "\"2025-04-26\"")
            ]),
        .target(
            name: "QuickJSC",
            dependencies: ["QuickJSCore"],
            path: "Sources/QuickJSC",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../../Vendor/QuickJS")
            ]),
        .target(
            name: "PluginCore",
            dependencies: [
                "QuickJSC",
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
