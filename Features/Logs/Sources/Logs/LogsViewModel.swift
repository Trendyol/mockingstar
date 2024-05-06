//
//  LogsViewModel.swift
//
//
//  Created by Yusuf Özgül on 8.11.2023.
//

import CommonKit
import Foundation
import SwiftUI

@Observable
final class LogsViewModel {
    private var allLogs: [LogModel] = []
    private var clearedLogs: [LogModel] = []
    private(set) var filteredLogs: [LogModel] = []
    var filterType: Set<LogSeverity> = [.critical, .error, .fault, .warning]
    var searchTerm: String = ""
    private let logStreamHandler: LogStreamHandlerInterface

    init(logStreamHandler: LogStreamHandlerInterface = LogStreamHandler.shared) {
        self.logStreamHandler = logStreamHandler
    }

    @MainActor
    func readLogs() async {
        allLogs = logStreamHandler.readAllLogs()
        filterLogs()

        for await log in logStreamHandler.stream() {
            allLogs.append(log)
            filterLogs()
        }
    }

    /// Filters the logs based on the current search term and filter type.
    @MainActor
    func filterLogs() {
        withAnimation {
            if searchTerm.isEmpty {
                filteredLogs = allLogs.filter { filterType.contains($0.severity) && !clearedLogs.contains($0) }.suffix(1000)
            } else {
                filteredLogs = allLogs.filter { $0.message.lowercased().contains(searchTerm.lowercased()) && filterType.contains($0.severity) && !clearedLogs.contains($0) }.suffix(1000)
            }
        }
    }

    @MainActor func clearLogs() {
        clearedLogs.append(contentsOf: filteredLogs)
        filterLogs()
    }
}
