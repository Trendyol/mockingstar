import CommonKit
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class ModifierChain {
    private let terminal: (URLRequest) async throws -> HTTPResult

    public init(modifiers: [ModifierModel],
                terminal: @escaping (URLRequest) async throws -> HTTPResult) {
        self.terminal = terminal
    }

    public func proceed(_ request: URLRequest) async throws -> HTTPResult {
        try await terminal(request)
    }
}
