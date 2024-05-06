// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CommonKit",
            targets: ["CommonKit"]),
        .library(
            name: "CommonKitTestSupport",
            targets: ["CommonKitTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/yusufozgul/AnyCodable", .upToNextMajor(from: "1.1.4")),
        .package(url: "https://github.com/aus-der-Technik/FileMonitor.git", from: "1.0.0"),
        .package(url: "https://github.com/swhitty/FlyingFox.git", .upToNextMajor(from: "0.12.1")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "CommonKit",
        dependencies: [
            "AnyCodable",
            "FlyingFox",
            .product(name: "FileMonitor", package: "FileMonitor"),
            .product(name: "Logging", package: "swift-log"),
        ]),
        .target(
            name: "CommonKitTestSupport",
            dependencies: ["CommonKit"]),
        .testTarget(
            name: "CommonKitTests",
            dependencies: ["CommonKit", "CommonKitTestSupport"]),
    ]
)
