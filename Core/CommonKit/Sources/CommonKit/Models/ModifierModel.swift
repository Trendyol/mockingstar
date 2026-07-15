import Foundation

public struct ModifierModel: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var path: String
    public var method: String
    public var scenario: String?
    public var enabled: Bool
    public var priority: Int
    public var sampleMockRequestId: String?
    public var transformerCode: String

    public init(id: String,
                path: String,
                method: String,
                scenario: String? = nil,
                enabled: Bool = false,
                priority: Int = 0,
                sampleMockRequestId: String? = nil,
                transformerCode: String) {
        self.id = id
        self.path = path
        self.method = method
        self.scenario = scenario
        self.enabled = enabled
        self.priority = priority
        self.sampleMockRequestId = sampleMockRequestId
        self.transformerCode = transformerCode
    }
}

public struct ModifierBulkUpdate: Codable, Hashable, Sendable {
    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}
