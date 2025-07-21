// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Editor",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Editor",
            targets: ["Editor"]),
        .library(
            name: "DiffEditor",
            targets: ["DiffEditor"]),
    ],
    dependencies: [
        .package(path: "../CommonKit"),
    ],
    targets: [
        .target(name: "Editor",
                dependencies: [
                    "CommonKit",
                ],
                resources: [
                    .copy("Resources/MonacoEditor"),
                ]),
        .target(name: "DiffEditor",
                resources: [
                    .copy("Resources/DiffEditor"),
                ]),

            .testTarget(name: "EditorTests",
                        dependencies: ["Editor"]),

            .testTarget(name: "DiffEditorTests",
                        dependencies: ["DiffEditor"]),
    ]
)
