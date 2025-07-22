//
//  MockingStar.swift
//
//
//  Created by Yusuf Özgül on 9.11.2023.
//

import CommonKit
import Foundation
import ArgumentParser

@main
struct MockingStar: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "MockingStar powerful mock server",
        subcommands: [Start.self, MockUsageAnalyzer.self],
        defaultSubcommand: Start.self)
}

private struct Start: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start Mocking Star")

    @Option(name: .shortAndLong, help: "Logs folder")
    var logsFolder: String? = nil

    @Option(name: .shortAndLong, help: "HTTP Server Port")
    var port: UInt16 = 8008

    @Argument(help: "Mocks folder path")
    var folder: String

    func run() async throws {
        @UserDefaultStorage("workspaces") var workspaces: [Workspace] = []
        workspaces = [Workspace(name: "Workspace", path: folder, bookmark: Data())]

        if let logsFolder, !logsFolder.isEmpty {
            Logger.Constant.customLogFolderPath = logsFolder
        }

        let server = HTTPServer(port: port)
        try await server.startServer()
    }
}

private struct MockUsageAnalyzer: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "analyze-usage",
        abstract: "Analyze previous mock usage from logs file")

    @Option(name: .shortAndLong, help: "Logs folder")
    var logsFolder: String

    @Flag(name: .shortAndLong, help: "Show Detailed Usage")
    var verbose: Bool = false

    func run() async throws {
        let fileURL: URL

        let customFolderExist = FileManager.default.fileOrDirectoryExists(atPath: logsFolder)
        if customFolderExist.isExist && customFolderExist.isDirectory {
            fileURL = URL(filePath: logsFolder).appending(path: "MockingStar.log")
        } else if customFolderExist.isExist {
            fileURL = URL(filePath: logsFolder)
        } else {
            fatalError("Custom mocks folder not exist.")
        }

        guard FileManager.default.fileOrDirectoryExists(atPath: fileURL.path()).isExist else {
            fatalError("Logs file not exist.")
        }

        var mockUsage: [String: Int] = [:]

        for try await line in fileURL.lines where line.contains("Mock Found:") {
            guard let id = line.components(separatedBy: " ").last else { continue }
            mockUsage[id] = mockUsage[id, default: 0] + 1
        }

        print("Total mock usage", mockUsage.values.reduce(0, +))

        if verbose {
            let sortedMocks = mockUsage.sorted { $0.value > $1.value }
            for (mockId, count) in sortedMocks {
                print("Mock ID: \(mockId) - usage: \(count)")
            }
        }
    }
}
