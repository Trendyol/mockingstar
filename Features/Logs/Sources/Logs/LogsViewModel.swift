//
//  LogsViewModel.swift
//
//
//  Created by Yusuf Özgül on 8.11.2023.
//

import CommonKit
import Foundation
import Combine
import SwiftUI

@Observable
final class LogsViewModel {
    private var allLogs: [LogModel] = []
    private var clearedLogs: [LogModel] = []
    private(set) var filteredLogs: [LogModel] = []
    private var cancellables = Set<AnyCancellable>()
    private let logsSubject: CurrentValueSubject<[LogModel], Never>

    var filterType: Set<LogSeverity> = Set(LogSeverity.allCases)
    var searchTerm: String = ""

    init(logsSubject: CurrentValueSubject<[LogModel], Never> = LogStorage.shared.logsSubject) {
        self.logsSubject = logsSubject
        registerStream()
    }

    /// Registers a stream to observe changes in logs and updates the UI accordingly.
    private func registerStream() {
        logsSubject
            .receive(on: DispatchQueue.main)
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .sink { [weak self] logs in
                self?.allLogs = logs
                self?.filterLogs()
            }
            .store(in: &cancellables)
    }

    /// Filters the logs based on the current search term and filter type.
    func filterLogs() {
        withAnimation {
            if searchTerm.isEmpty {
                filteredLogs = allLogs.filter { filterType.contains($0.severity) && !clearedLogs.contains($0) }.suffix(1000)
            } else {
                filteredLogs = allLogs.filter { $0.message.lowercased().contains(searchTerm.lowercased()) && filterType.contains($0.severity) && !clearedLogs.contains($0) }.suffix(1000)
            }
        }
    }

    func clearLogs() {
        clearedLogs.append(contentsOf: filteredLogs)
        filterLogs()
    }
}
