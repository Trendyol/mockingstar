import CommonKit
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ModifierExecutionMode: String, Sendable {
    case runtime
    case preview
}

public final class ModifierChain {
    private let terminal: (URLRequest) async throws -> HTTPResult

    public init(modifiers: [ModifierModel],
                executionMode: ModifierExecutionMode = .runtime,
                terminal: @escaping (URLRequest) async throws -> HTTPResult) {
        _ = executionMode
        self.terminal = terminal
    }

    public func proceed(_ request: URLRequest) async throws -> HTTPResult {
        try await terminal(request)
    }
}
