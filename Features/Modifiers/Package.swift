// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Modifiers",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Modifiers",
            targets: ["Modifiers"]),
    ],
    dependencies: [
        .package(path: "../../Core/CommonKit"),
        .package(path: "../../Core/CommonViewsKit"),
        .package(path: "../../Core/Editor"),
        .package(path: "../../Core/MockingStarCore"),
        .package(path: "../../Core/Server"),
    ],
    targets: [
        .target(
            name: "Modifiers",
            dependencies: [
                "CommonKit",
                "CommonViewsKit",
                "Editor",
                "MockingStarCore",
                "Server",
            ]),
        .testTarget(
            name: "ModifiersTests",
            dependencies: [
                "Modifiers",
                .product(name: "CommonKitTestSupport", package: "CommonKit"),
                .product(name: "CommonViewsKitTestSupport", package: "CommonViewsKit"),
            ]),
    ]
)
