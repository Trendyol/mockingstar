import Foundation

/// Disk-backed modifier definition plus per-device activation status for API responses.
///
/// `id` is always the `.js` filename without extension. It is never persisted inside the JavaScript
/// file. `enabled` is also not persisted; callers compute it from the ephemeral per-device
/// activation set before returning models over the API.
public struct ModifierModel: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var path: String
    public var method: String
    public var scenario: String?
    public var enabled: Bool
    public var source: ModifierPreviewSource?
    public var order: Int
    public var sampleMockRequestId: String?
    /// JavaScript containing `function transformer(req, chain) { ... }` (metadata is not required).
    public var transformerCode: String

    public init(id: String,
                path: String,
                method: String,
                scenario: String? = nil,
                enabled: Bool = false,
                source: ModifierPreviewSource? = nil,
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
public struct ModifierActivation: Codable, Hashable, Sendable {
    public let id: String
    public var source: ModifierPreviewSource

    public init(id: String, source: ModifierPreviewSource) {
        self.id = id
        self.source = source
    }
}

/// Writable payload for creating or updating a modifier definition.
///
/// On create, `id` chooses the filename. On update, the path segment identifies the current
/// modifier and a different body `id` requests a filename rename.
public struct ModifierWriteRequest: Codable, Hashable, Sendable {
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

    public func asModel(id: String, enabled: Bool = false) -> ModifierModel {
        ModifierModel(id: id,
                      path: path,
                      method: method,
                      scenario: scenario,
                      enabled: enabled,
                      order: order,
                      sampleMockRequestId: sampleMockRequestId,
                      transformerCode: transformerCode)
    }
}
