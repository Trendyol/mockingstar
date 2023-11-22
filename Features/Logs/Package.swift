// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Logs",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Logs",
            targets: ["Logs"]),
    ],
    dependencies: [
        .package(path: "../../Core/CommonKit"),
        .package(path: "../../Core/CommonViewsKit"),
    ],
    targets: [
        .target(
            name: "Logs",
            dependencies: ["CommonKit", "CommonViewsKit"]),
        .testTarget(
            name: "LogsTests",
            dependencies: ["Logs"]),
    ]
)
