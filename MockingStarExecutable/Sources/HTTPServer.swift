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

        let MockingStarCore = MockingStarCore()
        server.registerMockHandler(MockingStarCore)
        server.registerScenarioHandler(MockingStarCore)
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
