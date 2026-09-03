//
//  TimedMockHandler.swift
//
//
//  Created by Maide Başak Karahan on 3.09.2026.
//

import CommonKit
import Foundation
import Server

final class TimedMockHandler: ServerMockHandlerInterface {
    private let wrapped: ServerMockHandlerInterface
    private let threshold: Double
    private let logger = Logger(category: "CLI")
    private let clock = ContinuousClock()

    init(wrapping wrapped: ServerMockHandlerInterface, threshold: Double) {
        self.wrapped = wrapped
        self.threshold = threshold
    }

    func handle(url: URL, method: String, headers: [String: String], body: Data?, rawFlags: [String: String]) async throws -> (status: Int, body: Data, headers: [String: String]) {
        let start = clock.now
        let result = try await wrapped.handle(url: url, method: method, headers: headers, body: body, rawFlags: rawFlags)
        let duration = clock.now - start
        let durationSeconds = duration.seconds

        if durationSeconds > threshold {
            let durationText = String(format: "%.2f", durationSeconds)
            let thresholdText = String(format: "%.2f", threshold)
            logger.warning("Mock response exceeded threshold: \(durationText)s (threshold: \(thresholdText)s) \(method) \(url.absoluteString)")
        }

        return result
    }
}

private extension Duration {
    var seconds: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
