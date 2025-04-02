//
//  MockTraceOverlayViewModel.swift
//  MockList
//
//  Created by Yusuf Özgül on 28.03.2025.
//

import Foundation
import CommonKit
import SwiftUI

@Observable
final class MockTraceOverlayViewModel {
    private let logStreamHandler: LogStreamHandlerInterface
    private(set) var logs: [LogModel] = []

    init(logStreamHandler: LogStreamHandlerInterface = LogStreamHandler.shared) {
        self.logStreamHandler = logStreamHandler
        Task { [weak self] in await self?.readLogs() }
    }

    @MainActor
    func readLogs() async {
        logs = logStreamHandler.readAllLogs()
            .filter { $0.message == "Mock Trace" }

        for await log in logStreamHandler.stream() {
            withAnimation {
                if log.message == "Mock Trace" { logs.append(log) }
            }
        }
    }

    func clearLogs() {
        logs.removeAll()
    }
}
