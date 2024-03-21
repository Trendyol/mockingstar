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

    func startServer() {
        server.startServer { error in
            guard !(error is CancellationError) else { return }
            fatalError(error.localizedDescription)
        }
    }

    func stopServer() {
        server.stopServer()
    }
}
