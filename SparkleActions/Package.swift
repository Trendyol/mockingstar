// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SparkleActions",
    dependencies: [
        .package(url: "https://github.com/johnsundell/ink.git", from: "0.6.0"),
    ],
    targets: [
        .executableTarget(name: "SparkleActions", dependencies: [
            .product(name: "Ink", package: "ink"),
        ]),
    ]
)
