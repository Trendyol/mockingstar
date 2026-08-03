import Foundation

protocol RequestReloaderPlugin {
    var config: [PluginConfiguration] { get throws }
    func updateRequest(request: URLRequestModel) throws -> URLRequestModel
}

final class RequestReloaderPluginJSBridge: PluginJavaScriptBridge, RequestReloaderPlugin {
    func updateRequest(request: URLRequestModel) throws -> URLRequestModel {
        try call("updateRequest", arguments: [request])
    }
}
