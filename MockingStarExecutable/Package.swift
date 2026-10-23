// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MockingStarExecutable",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mockingstar", targets: ["MockingStar"]),
    ],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "MockingStar",
            dependencies: [
                .product(name: "MockingstarEngine", package: "mockingstar"),
            ]),
    ]
)
