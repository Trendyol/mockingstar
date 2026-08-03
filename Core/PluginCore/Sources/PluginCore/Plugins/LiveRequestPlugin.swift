import Foundation

protocol LiveRequestPlugin {
    var config: [PluginConfiguration] { get throws }
    func updateRequest(request: URLRequestModel) throws -> URLRequestModel
}

final class LiveRequestPluginJSBridge: PluginJavaScriptBridge, LiveRequestPlugin {
    func updateRequest(request: URLRequestModel) throws -> URLRequestModel {
        try call("updateRequest", arguments: [request])
    }
}
