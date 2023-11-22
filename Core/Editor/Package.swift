// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Editor",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "JSONEditor",
            targets: ["JSONEditor"]),
        .library(
            name: "DiffEditor",
            targets: ["DiffEditor"]),
    ],
    targets: [
        .target(name: "JSONEditor",
                resources: [
                    .copy("Resources/MonacoEditor"),
                ]),
        .target(name: "DiffEditor",
                resources: [
                    .copy("Resources/DiffEditor"),
                ]),

            .testTarget(name: "JSONEditorTests",
                        dependencies: ["JSONEditor"]),

            .testTarget(name: "DiffEditorTests",
                        dependencies: ["DiffEditor"]),
    ]
)
