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
    ],
    targets: [
        .target(
            name: "MockList",
            dependencies: [
                "CommonKit",
                "CommonViewsKit",
                "MockingStarCore",
            ]),
        .testTarget(
            name: "MockListTests",
            dependencies: [
                "MockList",
                .product(name: "MockingStarCoreTestSupport", package: "MockingStarCore"),
                .product(name: "CommonKitTestSupport", package: "CommonKit"),
            ]),
    ]
)
