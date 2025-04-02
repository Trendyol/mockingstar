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
    private(set) var filteredLogs: [LogModel] = []

    @ObservationIgnored
    var filterType: Set<LogSeverity> {
        get {
            access(keyPath: \.filterType)
            @UserDefaultStorage("logsFilterType") var filters: Set<LogSeverity> = [.critical, .error, .fault, .warning]
            return filters
        } set {
            withMutation(keyPath: \.filterType) {
                @UserDefaultStorage("logsFilterType") var filters: Set<LogSeverity> = []
                filters = newValue
            }
        }
    }
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
            withAnimation {
                if filter(log) { filteredLogs.append(log) }
            }
        }
    }

    @MainActor
    func filterLogs() {
        withAnimation {
            filteredLogs = allLogs.filter(filter(_:)).suffix(1000)
        }
    }

    /// Filters the logs based on the current search term and filter type.
    @MainActor
    private func filter(_ log: LogModel) -> Bool {
        if searchTerm.isEmpty {
            if filterType.contains(log.severity) { return true }
        } else {
            if filterType.contains(log.severity),
               log.message.localizedLowercase.contains(searchTerm.localizedLowercase) || log.metadata.values.map(\.localizedLowercase).contains(searchTerm.localizedLowercase) {
                return true
            }
        }

        return false
    }

    @MainActor func clearLogs() {
        allLogs.removeAll()
        filterLogs()
    }
}
