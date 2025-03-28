// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Server",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Server",
            targets: ["Server"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swhitty/FlyingFox.git", exact: "0.13.0"),
        .package(path: "../CommonKit"),
    ],
    targets: [
        .target(
            name: "Server",
            dependencies: [
                "CommonKit",
                "FlyingFox",
            ]),
        .testTarget(
            name: "ServerTests",
            dependencies: ["Server"]),
    ]
)
