import CommonKit
import Foundation
import MockingStarCore
import Server

enum MockModifierAPIError: LocalizedError, Equatable {
    case conflict
    case badRequest
    case notFound
    case executionFailed(String)
    case liveRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .conflict: return "A modifier with this id already exists"
        case .badRequest: return "Invalid modifier request"
        case .notFound: return "Modifier not found"
        case .executionFailed(let message): return message
        case .liveRequestFailed(let message): return message
        }
    }
}

public protocol MockModifierAPIClientInterface {
    func listModifiers(domain: String) async throws -> [MockModifierModel]
    func getModifier(domain: String, id: String) async throws -> MockModifierModel
    func createModifier(domain: String, request: MockModifierWriteRequest) async throws
    func updateModifier(domain: String, id: String, request: MockModifierWriteRequest) async throws
    func deleteModifier(domain: String, id: String) async throws
    func setActiveModifiers(domain: String, activations: [MockModifierActivation]) async throws
    func previewModifier(domain: String, request: MockModifierPreviewRequest) async throws -> MockModifierPreviewResponse
}

/// Uses the core's shared modifier stores directly; UI operations do not need a running HTTP server.
public final class MockModifierAPIClient: MockModifierAPIClientInterface {
    private let handler: ServerMockModifierHandlerInterface

    public init(handler: ServerMockModifierHandlerInterface = MockingStarCore()) {
        self.handler = handler
    }

    public func listModifiers(domain: String) async throws -> [MockModifierModel] {
        try await perform { try await handler.listModifiers(domain: domain, deviceId: "") }
    }

    public func getModifier(domain: String, id: String) async throws -> MockModifierModel {
        try await perform {
            guard let model = try await handler.getModifier(domain: domain, id: id, deviceId: "") else {
                throw MockModifierAPIError.notFound
            }
            return model
        }
    }

    public func createModifier(domain: String, request: MockModifierWriteRequest) async throws {
        guard let id = request.id, !id.isEmpty else { throw MockModifierAPIError.badRequest }
        try await perform { try await handler.createModifier(domain: domain, model: request.asModel(id: id)) }
    }

    public func updateModifier(domain: String, id: String, request: MockModifierWriteRequest) async throws {
        try await perform {
            try await handler.updateModifier(domain: domain, currentId: id, model: request.asModel(id: request.id ?? id))
        }
    }

    public func deleteModifier(domain: String, id: String) async throws {
        try await perform { try await handler.deleteModifier(domain: domain, id: id) }
    }

    public func setActiveModifiers(domain: String, activations: [MockModifierActivation]) async throws {
        try await perform { try await handler.setActiveModifiers(domain: domain, deviceId: "", activations: activations) }
    }

    public func previewModifier(domain: String, request: MockModifierPreviewRequest) async throws -> MockModifierPreviewResponse {
        try await perform { try await handler.previewModifier(domain: domain, deviceId: "", request: request) }
    }

    private func perform<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as ServerMockModifierError {
            switch error {
            case .alreadyExists, .previewConflict:
                throw MockModifierAPIError.conflict
            case .notFound, .previewNotFound:
                throw MockModifierAPIError.notFound
            case .invalidId, .unknownIds, .duplicateIds, .previewInvalidRequest:
                throw MockModifierAPIError.badRequest
            case .previewExecutionFailed(let message):
                throw MockModifierAPIError.executionFailed(message)
            case .previewLiveRequestFailed(let message):
                throw MockModifierAPIError.liveRequestFailed(message)
            }
        }
    }
}
