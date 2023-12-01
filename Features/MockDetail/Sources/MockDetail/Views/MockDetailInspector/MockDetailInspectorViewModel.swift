//
//  File.swift
//
//
//  Created by Yusuf Özgül on 25.10.2023.
//

import CommonKit
import PluginCore
import SwiftUI

@Observable
final class MockDetailInspectorViewModel {
    private let logger = Logger(category: "MockDetailInspectorViewModel")
    let mockDomain: String
    let mockModel: MockModel
    var scenario: String
    var httpStatus: Int
    var responseTime: Double
    var pluginMessages: [String] = []
    var onChange: () -> Void

    init(mockDomain: String, mockModel: MockModel, onChange: @escaping () -> Void) {
        self.mockDomain = mockDomain
        self.mockModel = mockModel
        self.scenario = mockModel.metaData.scenario
        self.httpStatus = mockModel.metaData.httpStatus
        self.responseTime = mockModel.metaData.responseTime
        self.onChange = onChange
    }

    func sync() {
        mockModel.metaData.scenario = scenario
        mockModel.metaData.httpStatus = httpStatus
        mockModel.metaData.responseTime = responseTime
        onChange()
    }

    @MainActor
    func loadPluginMessage() async {
        pluginMessages.removeAll()
        do {
            let plugin = await PluginCoreActor.shared.pluginCore(for: mockDomain)
            pluginMessages.append(try plugin.mockDetailMessagePlugin(mock: mockModel))
            pluginMessages.append(try await plugin.asyncMockDetailMessagePlugin(mock: mockModel))
            pluginMessages.removeAll(where: \.isEmpty)
        } catch {
            logger.error("Mock Detail Plugin Error: \(error)")
        }
    }
}
