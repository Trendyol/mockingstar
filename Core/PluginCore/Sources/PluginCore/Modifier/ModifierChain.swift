import CommonKit
import Foundation

enum ModifierChainError: Error {
    case chainDeallocated
}

/// Orchestrates an ordered list of already-matched modifiers around a terminal handler.
///
/// Modifiers are expected to be pre-sorted (priority asc, then id asc) by the caller
/// (see `ModifierMatcher`). Index 0 is the outermost transformer; when the index reaches
/// `modifiers.count`, `proceed` invokes `terminal` — the existing mock/live resolution.
public final class ModifierChain {
    private let modifiers: [ModifierModel]
    private let terminal: (URLRequest) async throws -> HTTPResult
    private let executor = ModifierExecutor()
    private let logger = Logger(category: "ModifierChain")
    private let lock = NSLock()
    private var index = 0

    public init(modifiers: [ModifierModel],
                terminal: @escaping (URLRequest) async throws -> HTTPResult) {
        self.modifiers = modifiers
        self.terminal = terminal
    }

    public func proceed(_ request: URLRequest) async throws -> HTTPResult {
        let currentIndex = nextIndex()

        guard currentIndex < modifiers.count else {
            return try await terminal(request)
        }

        let modifier = modifiers[currentIndex]

        return try executor.execute(modifier: modifier, request: request) { [weak self] innerRequest in
            guard let self else {
                throw ModifierChainError.chainDeallocated
            }

            let semaphore = DispatchSemaphore(value: 0)
            var outcome: Result<HTTPResult, Error> = .success(HTTPResult(status: 500, body: Data(), headers: [:]))

            Task {
                do {
                    outcome = .success(try await self.proceed(innerRequest))
                } catch {
                    self.logger.error("Modifier chain proceed failed: \(error)")
                    outcome = .failure(error)
                }
                semaphore.signal()
            }

            semaphore.wait()
            // Rethrow on failure (rather than returning a dummy 500 HTTPResult) so the
            // JS bridge (`JSChain`) can surface this as a JS exception, preventing the
            // *outer* transformer from mutating/hiding the failure behind a success response.
            return try outcome.get()
        }
    }

    private func nextIndex() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let current = index
        index += 1
        return current
    }
}
