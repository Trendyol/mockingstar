// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MockDetail",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MockDetail",
            targets: ["MockDetail"]),
    ],
    dependencies: [
        .package(path: "../../Core/CommonViewsKit"),
        .package(path: "../../Core/PluginCore"),

        .package(path: "../../Core/Editor"),
    ],
    targets: [
        .target(
            name: "MockDetail",
        dependencies: [
            .product(name: "JSONEditor", package: "Editor"),
            .product(name: "DiffEditor", package: "Editor"),
            "CommonViewsKit",
            "PluginCore",
        ]),
        .testTarget(
            name: "MockDetailTests",
            dependencies: ["MockDetail"]),
    ]
)
