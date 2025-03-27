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
struct MockingStar: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "MockingStar powerful mock server",
        subcommands: [Start.self],
        defaultSubcommand: Start.self)

    struct Start: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start mock server")

        @Option(name: .shortAndLong, help: "Logs folder")
        var logsFolder: String? = nil

        @Option(name: .shortAndLong, help: "HTTP Server Port")
        var port: UInt16 = 8008

        @Argument(help: "Mocks folder path")
        var folder: String

        func run() throws {
            @UserDefaultStorage("workspaces") var workspaces: [Workspace] = []
            workspaces = [Workspace(name: "Workspace", path: folder, bookmark: Data())]

            if let logsFolder, !logsFolder.isEmpty {
                Logger.Constant.logsWriteFilePath = logsFolder
            }
            
            let server = HTTPServer(port: port)
            server.startServer()

            RunLoop.main.run()
        }
    }

    struct Stop: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop mock server")

        func run() throws {

        }
    }
}
