import CommonKit
import Foundation

protocol MockDetailHelperPlugin {
    var config: [PluginConfiguration] { get throws }
    func mockDetailMessages(path: String, scenario: String, mock: MockModel) throws -> String
    func asyncMockDetailMessages(mock: MockModel) async throws -> String
}

final class MockDetailHelperPluginJSBridge: PluginJavaScriptBridge, MockDetailHelperPlugin {
    func mockDetailMessages(path: String, scenario: String, mock: MockModel) throws -> String {
        try call("mockDetailMessages", arguments: [path, scenario, mock])
    }

    func asyncMockDetailMessages(mock: MockModel) async throws -> String {
        try await call("asyncMockDetailMessages", arguments: [mock])
    }
}
