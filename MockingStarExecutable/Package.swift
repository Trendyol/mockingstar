// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MockingStarExecutable",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../Core/CommonKit"),
        .package(path: "../Core/PluginCore"),
        .package(path: "../Core/MockingStarCore"),
        .package(path: "../Core/Server"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "MockingStar",
            dependencies: [
                "CommonKit",
                .product(name: "PluginCore", package: "PluginCore", condition: .when(platforms: [.macOS])),
                .product(name: "PluginCoreLinux", package: "PluginCore", condition: .when(platforms: [.linux])),
                "MockingStarCore",
                "Server",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
    ]
)
