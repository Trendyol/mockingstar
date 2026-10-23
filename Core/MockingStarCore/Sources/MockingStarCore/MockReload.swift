import Foundation
import CommonKit
#if os(macOS)
import PluginCore
#else
import PluginCoreLinux
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct MockReloadResult: Codable {
    public let changed: [String]
    public let previous: MockModel
    public let current: MockModel
}

public extension MockingStarCore {
    func reload(mock: MockModel, domain: String, root: URL) async throws -> MockReloadResult {
        try MockWorkspace(root: root).checkDomain(domain)
        let plugin = await PluginCoreActor(fileUrlBuilder: FileUrlBuilder(root: root), settingsRoot: root).pluginCore(for: domain)
        let updated = try plugin.requestReloaderPlugin(request: .init(url: mock.metaData.url.absoluteString, headers: try mock.requestHeader.asDictionary(), body: mock.requestBody, method: mock.metaData.method))
        guard let url = URL(string: updated.url), ["http", "https"].contains(url.scheme ?? "") else { throw WorkspaceFailure("invalid_url", "Reload plugin returned invalid URL") }
        var request = URLRequest(url: url); request.httpMethod = updated.method; request.allHTTPHeaderFields = updated.headers
        request.httpBody = updated.body.isEmpty ? nil : Data(updated.body.utf8)
        let started = Date()
        let (data, response) = try await URLSession.shared.data(for: request.recalculateContentLength())
        guard let response = response as? HTTPURLResponse, let body = String(data: data, encoding: .utf8) else { throw WorkspaceFailure("invalid_response", "Reload requires an HTTP response with UTF-8 body") }
        let current = mock.copy() as! MockModel
        current.responseBody = body; current.responseHeader = .init(response.headersDictionary)
        current.metaData.httpStatus = response.statusCode; current.metaData.responseTime = Date().timeIntervalSince(started); current.metaData.updateTime = Date()
        var changed: [String] = []
        if current.metaData.httpStatus != mock.metaData.httpStatus { changed.append("status") }
        if try current.responseHeader.asDictionary() != mock.responseHeader.asDictionary() { changed.append("headers") }
        if current.responseBody != mock.responseBody { changed.append("body") }
        return .init(changed: changed, previous: mock, current: current)
    }
}
