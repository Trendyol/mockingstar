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
    var filterType: Set<LogSeverity> = Set(LogSeverity.allCases)
    var searchTerm: String = ""

    init(logsStream: AsyncStream<[LogModel]> = LogStorage.shared.allLogsStream) {
        Task { @MainActor in
            for await logs in logsStream {
                allLogs = logs
                filterLogs()
            }
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
