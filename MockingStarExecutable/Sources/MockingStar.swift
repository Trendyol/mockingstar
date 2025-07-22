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
        subcommands: [Start.self],
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

            }
        }
    }
}
