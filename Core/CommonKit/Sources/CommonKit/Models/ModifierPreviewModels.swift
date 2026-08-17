import Foundation

public enum ModifierPreviewSource: String, Codable, Hashable, Sendable {
    case mock
    case live
}

public struct ModifierPreviewHTTPRequest: Codable, Hashable, Sendable {
    public var url: URL
    public var method: String
    public var scenario: String?
    public var headers: [String: String]
    public var bodyBase64: String

    public init(
        url: URL,
        method: String,
        scenario: String? = nil,
        headers: [String: String] = [:],
        bodyBase64: String = ""
    ) {
        self.url = url
        self.method = method
        self.scenario = scenario
        self.headers = headers
        self.bodyBase64 = bodyBase64
    }
}

public struct ModifierPreviewRequest: Codable, Hashable, Sendable {
    public var currentModifierId: String
    public var modifier: ModifierWriteRequest
    public var request: ModifierPreviewHTTPRequest
    public var source: ModifierPreviewSource

    public init(
        currentModifierId: String,
        modifier: ModifierWriteRequest,
        request: ModifierPreviewHTTPRequest,
        source: ModifierPreviewSource
    ) {
        self.currentModifierId = currentModifierId
        self.modifier = modifier
        self.request = request
        self.source = source
    }
}

public struct ModifierPreviewResponse: Codable, Hashable, Sendable {
    public var status: Int
    public var headers: [String: String]
    public var bodyBase64: String

    public init(status: Int, headers: [String: String], bodyBase64: String) {
        self.status = status
        self.headers = headers
        self.bodyBase64 = bodyBase64
    }
}

public struct ModifierAPIErrorResponse: Codable, Hashable, Sendable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}
