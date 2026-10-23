// swift-tools-version: 5.9
import PackageDescription

// Headless products share the GUI's core sources without importing SwiftUI.
#if os(macOS)
let plugins: [Target.Dependency] = ["PluginCore"]
let pluginTarget = Target.target(name: "PluginCore", dependencies: ["CommonKit", .product(name: "AnyCodable", package: "AnyCodable"), .product(name: "SwiftyJS", package: "SwiftyJS")], path: "Core/PluginCore/Sources/PluginCore")
let javascriptDependencies: [Package.Dependency] = [.package(url: "https://github.com/baris-cakmak/SwiftyJS.git", revision: "b39e24e84c23196b63a4f4f8c096c3f2e221d69a")]
#else
let plugins: [Target.Dependency] = ["PluginCoreLinux"]
let pluginTarget = Target.target(name: "PluginCoreLinux", dependencies: ["CommonKit", .product(name: "AnyCodable", package: "AnyCodable")], path: "Core/PluginCore/Sources/PluginCoreLinux")
let javascriptDependencies: [Package.Dependency] = []
#endif

let package = Package(
    name: "Mockingstar",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MockingstarEngine", targets: ["MockingstarEngine"]),
        .library(name: "MockingStarCore", targets: ["MockingStarCore"]),
        .library(name: "CommonKit", targets: ["CommonKit"]),
        .executable(name: "mockingstar", targets: ["MockingStarCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/yusufozgul/AnyCodable", exact: "1.1.4"),
        .package(url: "https://github.com/aus-der-Technik/FileMonitor.git", exact: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.3"),
        .package(url: "https://github.com/swhitty/FlyingFox.git", exact: "0.13.0")
    ] + javascriptDependencies,
    targets: [
        .target(name: "CommonKit", dependencies: [
            .product(name: "AnyCodable", package: "AnyCodable"),
            .product(name: "FileMonitor", package: "FileMonitor"),
            .product(name: "Logging", package: "swift-log")
        ], path: "Core/CommonKit/Sources/CommonKit", exclude: ["Models/OnboardingCompleted.swift"]),
        .target(name: "Server", dependencies: ["CommonKit", .product(name: "FlyingFox", package: "FlyingFox")], path: "Core/Server/Sources/Server"),
        pluginTarget,
        .target(name: "MockingStarCore", dependencies: ["CommonKit", "Server"] + plugins, path: "Core/MockingStarCore/Sources/MockingStarCore", exclude: ["MockDomainDiscover.swift"]),
        .target(name: "MockingstarEngine", dependencies: ["CommonKit", "MockingStarCore", "Server", .product(name: "FlyingSocks", package: "FlyingFox")] + plugins, path: "MockingStarEngine/Sources/MockingstarEngine"),
        .executableTarget(name: "MockingStarCLI", dependencies: ["MockingstarEngine"], path: "MockingStarExecutable/Sources"),
        .testTarget(name: "MockingstarEngineTests", dependencies: ["MockingstarEngine", "MockingStarCore"], path: "MockingStarEngine/Tests/MockingstarEngineTests")
    ]
)
