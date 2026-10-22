import CommonKit
import Foundation

enum MockModifierChainError: Error {
    case chainDeallocated
}

public enum MockModifierExecutionMode: String, Sendable {
    case runtime
    case preview
}

/// Orchestrates an ordered list of already-matched modifiers around a terminal handler.
///
/// Modifiers are expected to be pre-sorted (order asc, then id asc) by the caller
/// (see `MockModifierMatcher`). Index 0 is the outermost transformer; when the index reaches
/// `modifiers.count`, `proceed` invokes `terminal` — the existing mock/live resolution.
public final class MockModifierChain {
    private let modifiers: [MockModifierModel]
    private let executionMode: MockModifierExecutionMode
    private let terminal: (URLRequest) async throws -> HTTPResult
    private let executor = MockModifierExecutor()
    private let logger = Logger(category: "MockModifierChain")
    private let lock = NSLock()
    private var index = 0

    public init(modifiers: [MockModifierModel],
                executionMode: MockModifierExecutionMode = .runtime,
                terminal: @escaping (URLRequest) async throws -> HTTPResult) {
        self.modifiers = modifiers
        self.executionMode = executionMode
        self.terminal = terminal
    }

    public func proceed(_ request: URLRequest) async throws -> HTTPResult {
        let currentIndex = nextIndex()

        guard currentIndex < modifiers.count else {
            return try await terminal(request)
        }

        let modifier = modifiers[currentIndex]

        // JS chain.proceed is synchronous and waits for an async terminal. Run each
        // transformer on Dispatch so those waits cannot exhaust Swift's cooperative pool.
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do {
                    let result = try executor.execute(
                        modifier: modifier,
                        request: request,
                        executionMode: executionMode
                    ) { [weak self] innerRequest in
                        guard let self else {
                            throw MockModifierChainError.chainDeallocated
                        }

                        let semaphore = DispatchSemaphore(value: 0)
                        var outcome: Result<HTTPResult, Error> = .success(HTTPResult(status: 500, body: Data(), headers: [:]))

                        Task {
                            do {
                                outcome = .success(try await self.proceed(innerRequest))
                            } catch {
                                self.logger.error("modifier chain proceed failed: \(error)")
                                outcome = .failure(error)
                            }
                            semaphore.signal()
                        }

                        semaphore.wait()
                        // Propagate errors through JSChain so outer modifiers cannot hide a failure.
                        return try outcome.get()
                    }
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
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
