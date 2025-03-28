// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MockList",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MockList",
            targets: ["MockList"]),
    ],
    dependencies: [
        .package(path: "../../Core/CommonKit"),
        .package(path: "../../Core/CommonViewsKit"),
        .package(path: "../../Core/MockingStarCore"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "MockList",
            dependencies: [
                "CommonKit",
                "CommonViewsKit",
                "MockingStarCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .testTarget(
            name: "MockListTests",
            dependencies: [
                "MockList",
                .product(name: "MockingStarCoreTestSupport", package: "MockingStarCore"),
                .product(name: "CommonKitTestSupport", package: "CommonKit"),
                .product(name: "CommonViewsKitTestSupport", package: "CommonViewsKit"),
            ]),
    ]
)
