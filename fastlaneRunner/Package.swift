// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "fastlaneRunner",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/fastlane/fastlane", from: "2.179.0"),
        .package(url: "https://github.com/johnsundell/ink.git", from: "0.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "fastlaneRunner",
            dependencies: [
                .product(name: "Ink", package: "ink"),
                .product(name: "Fastlane", package: "fastlane"),
            ]
        ),
    ]
)
