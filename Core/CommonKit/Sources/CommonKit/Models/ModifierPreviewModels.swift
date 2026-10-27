import Foundation

public enum MockModifierPreviewSource: String, Codable, Hashable, Sendable {
    case mock
    case live
}

public struct MockModifierPreviewHTTPRequest: Codable, Hashable, Sendable {
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

public struct MockModifierPreviewRequest: Codable, Hashable, Sendable {
    public var currentModifierId: String
    public var modifier: MockModifierWriteRequest
    public var request: MockModifierPreviewHTTPRequest
    public var source: MockModifierPreviewSource

    public init(
        currentModifierId: String,
        modifier: MockModifierWriteRequest,
        request: MockModifierPreviewHTTPRequest,
        source: MockModifierPreviewSource
    ) {
        self.currentModifierId = currentModifierId
        self.modifier = modifier
        self.request = request
        self.source = source
    }
}

public struct MockModifierPreviewResponse: Codable, Hashable, Sendable {
    public var status: Int
    public var headers: [String: String]
    public var bodyBase64: String
    public var originalStatus: Int?
    public var originalHeaders: [String: String]?
    public var originalBodyBase64: String?

    public init(status: Int,
                headers: [String: String],
                bodyBase64: String,
                originalStatus: Int? = nil,
                originalHeaders: [String: String]? = nil,
                originalBodyBase64: String? = nil) {
        self.status = status
        self.headers = headers
        self.bodyBase64 = bodyBase64
        self.originalStatus = originalStatus
        self.originalHeaders = originalHeaders
        self.originalBodyBase64 = originalBodyBase64
    }
}

public struct MockModifierAPIErrorResponse: Codable, Hashable, Sendable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}
