//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 9.11.2023.
//

import Foundation
import Server
import MockingStarCore

final class HTTPServer {
    private let server: ServerInterface

    init(port: UInt16) {
        server = Server(port: port)

        let mockingStarCore = MockingStarCore()
        server.registerMockHandler(mockingStarCore)
        server.registerMockSearchHandler(mockingStarCore)
        server.registerScenarioHandler(mockingStarCore)
    }

    func startServer() async throws {
        do {
            try await server.startServer()
        } catch {
            guard !(error is CancellationError) else { return }
            throw error
        }
    }

    func stopServer() {
        server.stopServer()
    }
}
