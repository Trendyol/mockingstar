import CommonKit
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum MockModifierExecutionMode: String, Sendable {
    case runtime
    case preview
}

public final class MockModifierChain {
    private let terminal: (URLRequest) async throws -> HTTPResult

    public init(modifiers: [MockModifierModel],
                executionMode: MockModifierExecutionMode = .runtime,
                terminal: @escaping (URLRequest) async throws -> HTTPResult) {
        _ = executionMode
        self.terminal = terminal
    }

    public func proceed(_ request: URLRequest) async throws -> HTTPResult {
        try await terminal(request)
    }
}
