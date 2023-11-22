// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MockDomainConfigs",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MockDomainConfigs",
            targets: ["MockDomainConfigs"]),
    ],
    dependencies: [
        .package(path: "../../Core/CommonKit"),
        .package(path: "../../Core/CommonViewsKit"),
    ],
    targets: [
        .target(
            name: "MockDomainConfigs",
        dependencies: [
            "CommonKit",
            "CommonViewsKit",
        ]),
        .testTarget(
            name: "MockDomainConfigsTests",
            dependencies: ["MockDomainConfigs"]),
    ]
)
