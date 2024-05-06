//
//  SideBarServerViewModel.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 28.09.2023.
//

import CommonKit
import MockingStarCore
import Server
import SwiftUI

@Observable
final class SideBarServerViewModel {
    static let shared = SideBarServerViewModel()
    private(set) var serversUIModel: [ServerUIModel] = []
    private let defaultServers: [ServerInterface]

    private init() {
        @UserDefaultStorage("httpServerPort") var httpServerPort: UInt16 = 8008
        defaultServers = [
            Server(port: httpServerPort)
        ]
        prepareDefaultHTTPServer()
    }

    func prepareDefaultHTTPServer() {
        for server in defaultServers {
            let mockingStarCore = MockingStarCore()
            server.registerMockHandler(mockingStarCore)
            server.registerMockSearchHandler(mockingStarCore)
            server.registerScenarioHandler(mockingStarCore)

            let uiModel: ServerUIModel = .init(address: server.address,
                                               type: server.serverType,
                                               status: .stopped,
                                               id: server.id)
            serversUIModel.append(uiModel)
            startServer(serverUIModel: uiModel)
        }
    }

    func startServer(serverUIModel: ServerUIModel) {
        guard let server = defaultServers.first(where: { $0.id == serverUIModel.id }) else { return }
        serverUIModel.status = .running
        server.startServer { error in
            serverUIModel.status = .failed
            serverUIModel.errorMessage = error.localizedDescription
        }
    }

    func stopServer(serverUIModel: ServerUIModel) {
        guard let server = defaultServers.first(where: { $0.id == serverUIModel.id }) else { return }
        server.stopServer()
        serverUIModel.status = .stopped
    }
}

@Observable
class ServerUIModel: Identifiable, Hashable {
    let address: String
    let type: String
    var status: ServerStatus
    let id: UUID
    var errorMessage: String? = nil

    init(address: String, type: String, status: ServerStatus, id: UUID, errorMessage: String? = nil) {
        self.address = address
        self.type = type
        self.status = status
        self.id = id
        self.errorMessage = errorMessage
    }

    enum ServerStatus: String {
        case stopped, preparing, running, failed

        var color: Color {
            switch self {
            case .stopped: .gray
            case .preparing: .blue
            case .running: .green
            case .failed: .red
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(address)
        hasher.combine(type)
        hasher.combine(status)
        hasher.combine(id)
        hasher.combine(errorMessage)
    }

    static func == (lhs: ServerUIModel, rhs: ServerUIModel) -> Bool {
        lhs.address == rhs.address &&
        lhs.type == rhs.type &&
        lhs.status == rhs.status &&
        lhs.id == rhs.id &&
        lhs.errorMessage == rhs.errorMessage
    }
}
