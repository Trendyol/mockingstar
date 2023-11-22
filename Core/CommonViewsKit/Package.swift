// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonViewsKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CommonViewsKit",
            targets: ["CommonViewsKit"]),
    ],
    dependencies: [
        .package(path: "../CommonKit"),
    ],
    targets: [
        .target(
            name: "CommonViewsKit",
            dependencies: [
                "CommonKit",
            ]),
        .testTarget(
            name: "CommonViewsKitTests",
            dependencies: ["CommonViewsKit"]),
    ]
)
