import Foundation

public struct ModifierCreationSeed: Hashable, Sendable {
    public var mockId: String?
    public var url: String
    public var path: String
    public var method: String
    public var scenario: String
    public var requestHeadersJSON: String
    public var requestBody: String

    public init(
        mockId: String? = nil,
        url: String = "https://example.com/",
        path: String = "/",
        method: String = "GET",
        scenario: String = "",
        requestHeadersJSON: String = "{}",
        requestBody: String = ""
    ) {
        self.mockId = mockId
        self.url = url
        self.path = path
        self.method = method
        self.scenario = scenario
        self.requestHeadersJSON = requestHeadersJSON
        self.requestBody = requestBody
    }

    public init(mock: MockModel) {
        mockId = mock.id
        url = mock.metaData.url.absoluteString
        path = mock.metaData.url.path().isEmpty ? "/" : mock.metaData.url.path()
        method = mock.metaData.method
        scenario = mock.metaData.scenario
        requestHeadersJSON = mock.requestHeader
        requestBody = mock.requestBody
    }

    public static let empty = ModifierCreationSeed()
}
