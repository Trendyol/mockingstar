import Foundation

/// Disk-backed modifier definition plus per-device activation status for API responses.
///
/// `id` is always the `.js` filename without extension. It is never persisted inside the JavaScript
/// file. `enabled` is also not persisted; callers compute it from the ephemeral per-device
/// activation set before returning models over the API.
public struct MockModifierModel: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var path: String
    public var method: String
    public var scenario: String?
    public var enabled: Bool
    public var source: MockModifierPreviewSource?
    public var order: Int
    public var sampleMockRequestId: String?
    /// JavaScript containing `function transformer(req, chain) { ... }` (metadata is not required).
    public var transformerCode: String

    public init(id: String,
                path: String,
                method: String,
                scenario: String? = nil,
                enabled: Bool = false,
                source: MockModifierPreviewSource? = nil,
                order: Int = 1,
                sampleMockRequestId: String? = nil,
                transformerCode: String) {
        self.id = id
        self.path = path
        self.method = method
        self.scenario = scenario
        self.enabled = enabled
        self.source = source
        self.order = max(1, order)
        self.sampleMockRequestId = sampleMockRequestId
        self.transformerCode = transformerCode
    }
}

/// Activation payload for `PUT /modifiers`.
public struct MockModifierActivation: Codable, Hashable, Sendable {
    public let id: String
    public var source: MockModifierPreviewSource

    public init(id: String, source: MockModifierPreviewSource) {
        self.id = id
        self.source = source
    }
}

/// Create/update body. Unlike `MockModifierModel`, this has no `enabled` or `source`:
/// those come from the caller's device activation set, not from the file.
/// `id` is optional because update identifies the file by the URL path; a different
/// body `id` asks for a rename. `MockModifierModel.id` is always the current filename.
public struct MockModifierWriteRequest: Codable, Hashable, Sendable {
    public var id: String?
    public var path: String
    public var method: String
    public var scenario: String?
    public var order: Int
    public var sampleMockRequestId: String?
    public var transformerCode: String

    public init(id: String? = nil,
                path: String,
                method: String,
                scenario: String? = nil,
                order: Int = 1,
                sampleMockRequestId: String? = nil,
                transformerCode: String) {
        self.id = id
        self.path = path
        self.method = method
        self.scenario = scenario
        self.order = max(1, order)
        self.sampleMockRequestId = sampleMockRequestId
        self.transformerCode = transformerCode
    }

    public func asModel(id: String, enabled: Bool = false) -> MockModifierModel {
        MockModifierModel(id: id,
                      path: path,
                      method: method,
                      scenario: scenario,
                      enabled: enabled,
                      order: order,
                      sampleMockRequestId: sampleMockRequestId,
                      transformerCode: transformerCode)
    }
}
