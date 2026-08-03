import Foundation

protocol MockErrorPlugin {
    var config: [PluginConfiguration] { get throws }
    func defaultResponseModel(message: String) throws -> String
}

final class MockErrorPluginJSBridge: PluginJavaScriptBridge, MockErrorPlugin {
    func defaultResponseModel(message: String) throws -> String {
        try call("defaultResponseModel", arguments: [message])
    }
}
