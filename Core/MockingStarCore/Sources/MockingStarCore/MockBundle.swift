import Foundation
import CommonKit

/// Agent-friendly input. Native MockModel documents remain accepted unchanged.
public struct MockDefinition: Codable {
    public var id: String?
    public var url: URL
    public var method: String?
    public var headers: [String: String]?
    public var body: MatchValue?
    public var scenario: String?
    public var matching: MockMatching?
    public var response: Response
    public struct Response: Codable {
        public var status: Int?
        public var headers: [String: String]?
        public var body: MatchValue?
        public var delay: Double?
    }
    public func model() throws -> MockModel {
        let method = method ?? "GET"
        return MockModel(metaData: .init(url: url, method: method, appendTime: Date(), updateTime: Date(), httpStatus: response.status ?? 200, responseTime: response.delay ?? 0, scenario: scenario ?? "", id: id ?? UUID().uuidString),
                         requestHeader: .init(headers ?? [:]), responseHeader: .init(response.headers ?? [:]),
                         requestBody: try Self.text(body), responseBody: try Self.text(response.body),
                         matching: matching ?? .init(endpoint: .init(method: method, host: url.host ?? "", path: .init(value: url.path.isEmpty ? "/" : url.path))))
    }
    public static func text(_ value: MatchValue?) throws -> String {
        guard let value, value != .null else { return "" }
        if case .string(let text) = value { return text }
        return String(decoding: try JSONEncoder.shared.encode(value), as: UTF8.self)
    }
}

public enum MockBundle {
    public static func decode(_ data: Data) throws -> [MockModel] {
        let json = try JSONSerialization.jsonObject(with: data)
        let entries: [Any]
        if let array = json as? [Any] { entries = array }
        else if let object = json as? [String: Any], let mocks = object["mocks"] as? [Any] { entries = mocks }
        else { entries = [json] }
        guard !entries.isEmpty else { throw WorkspaceFailure("invalid_bundle", "Bundle requires at least one mock") }
        return try entries.map { entry in
            let data = try JSONSerialization.data(withJSONObject: entry)
            if (entry as? [String: Any])?["metaData"] != nil { return try JSONDecoder.shared.decode(MockModel.self, from: data) }
            return try JSONDecoder.shared.decode(MockDefinition.self, from: data).model()
        }
    }
}
