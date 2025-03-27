//
//  MockListViewModel.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 21.09.2023.
//

import CommonKit
import CommonViewsKit
import MockingStarCore
import SwiftUI

@Observable
public final class MockListViewModel {
    private let logger = Logger(category: "MockListViewModel")
    private let fileManager: FileManagerInterface
    private let mockDiscover: MockDiscoverInterface
    private let notificationManager: NotificationManagerInterface
    private let pasteBoard: NSPasteboardInterface

    private var listSortTask: Task<(), Never>? = nil
    private var reloadMocksTask: Task<(), Never>? = nil
    private var mockDomain: String = ""
    var sortOrder = [KeyPathComparator(\MockModel.metaData.updateTime, order: .forward)]
    var filterType: FilterType = .all
    var filterStyle: FilterStyle = .contains
    var searchTerm: String = ""
    var shouldShowDeleteConfirmation: Bool = false
    var selected = Set<MockModel.ID>()
    var isLoading: Bool = false
    var mockListCount: Int {
        get { mockListUIModel.count }
        set (newValue) { }
    }

    // MARK: Error
    var shouldShowErrorMessage = false
    var errorMessage: String = ""
    
    // MARK: Mock List
    private(set) var mockModelList: [MockModel] = []
    private(set) var mockListUIModel: [MockModel] = []

    public init(fileManager: FileManagerInterface = FileManager.default,
                mockDiscover: MockDiscoverInterface = MockDiscover(),
                notificationManager: NotificationManagerInterface = NotificationManager.shared,
                pasteBoard: NSPasteboardInterface = NSPasteboard.general) {
        self.fileManager = fileManager
        self.mockDiscover = mockDiscover
        self.notificationManager = notificationManager
        self.pasteBoard = pasteBoard
        listenMockDiscover()
    }

    private func listenMockDiscover() {
        Task {
            for await result in mockDiscover.mockDiscoverResult {
                switch result {
                case .loading:
                    isLoading = true
                    mockModelList.removeAll()
                case .result(let mocks):
                    isLoading = false
                    mockModelList = mocks
                    executeDeeplink()
                }
            }
        }
    }

    /// Searches and filters mock data based on the specified search term, filter type, and filter style.
    ///
    /// This asynchronous function performs a case-insensitive search on the mock model list based on the specified search term. It filters the mocks based on the selected filter type, filter style, and the specified conditions.
    func searchData() async {
        do {
            try Task.checkCancellation()
            let searchTerm = searchTerm.lowercased()

            guard !searchTerm.isEmpty else {
                try await MainActor.run {
                    try Task.checkCancellation()
                    mockListUIModel = mockModelList.sorted(using: sortOrder)
                }
                return
            }

            let filteredMocks = mockModelList.filter {
                let filterFields: [String] = switch filterType {
                case .all: [$0.metaData.url.path(), $0.metaData.url.query(), $0.metaData.scenario, $0.metaData.method, $0.id].compactMap { $0 }
                case .path: [$0.metaData.url.path()]
                case .query: [$0.metaData.url.query()].compactMap { $0 }
                case .scenario: [$0.metaData.scenario]
                case .method: [$0.metaData.method]
                case .statusCode: [$0.metaData.httpStatus.description]
                }

                return filterFields.contains { filterField in
                    let filterField = filterField.lowercased()

                    return switch filterStyle {
                    case .contains: filterField.contains(searchTerm)
                    case .notContains: !filterField.contains(searchTerm)
                    case .startWith: filterField.starts(with: searchTerm)
                    case .endWith: filterField.hasSuffix(searchTerm)
                    case .equal: filterField == searchTerm
                    case .notEqual: filterField != searchTerm
                    }
                }
            }

            try Task.checkCancellation()

            /// Find selected mocks, remove them if they are not included in the new UI list.
            selected
                .filter { id in !filteredMocks.contains(where: { $0.id == id }) }
                .forEach { selected.remove($0) }

            try Task.checkCancellation()

            try await MainActor.run {
                try Task.checkCancellation()
                mockListUIModel = filteredMocks.sorted(using: sortOrder)
            }
        } catch {
            guard !(error is CancellationError) else { return }
            logger.error("Mocks sorting error: \(error)")
        }
    }
    
    func mock(id: String) -> MockModel? {
        mockModelList.first(where: { $0.id == id })
    }
    
    func deleteSelectedMocks() {
        for select in selected {
            guard let mock = mock(id: select), let filePath = mock.fileURL?.path(percentEncoded: false) else { continue }

            do {
                try fileManager.removeFile(at: filePath)
            } catch {
                errorMessage = "Mock couldn't delete\n\(error)"
                shouldShowErrorMessage = true
            }
        }
        selected.removeAll()
    }
    
    @MainActor
    func mockDomainChanged(_ mockDomain: String) async {
        do {
            self.mockDomain = mockDomain
            try await mockDiscover.updateMockDomain(mockDomain)
        } catch {
            guard !(error is CancellationError) else { return }
            logger.error("Mock Domain Changed Error: \(error)")
        }
    }

    func reloadMocks() {
        reloadMocksTask?.cancel()
        reloadMocksTask = Task {
            do {
                try await mockDiscover.reloadMocks()
            } catch {
                guard !(error is CancellationError) else { return }
                logger.error("Mocks Reload Error: \(error)")
            }
        }
    }

    func shareButtonTapped(shareStyle: ShareStyle) {
        let mocks: [MockModel] =  selected.compactMap { mock(id: $0) }

        switch shareStyle {
        case .curl:
            let curlList = mocks.map(\.asURLRequest).map { $0.cURL(pretty: true) }
            pasteBoard.clearContents()
            pasteBoard.setString(curlList.joined(separator: "\n\n"), forType: .string)
        case .file:
            guard let mockModel = mocks.first else { return notificationManager.show(title: "File share only available for one mock", color: .red) }
            do {
                let data = try JSONEncoder.shared.encode(mockModel)
                guard let content = String(data: data, encoding: .utf8) else {
                    return notificationManager.show(title: "Failed to encode mock", color: .red)
                }
                pasteBoard.clearContents()
                pasteBoard.setString(content, forType: .string)
            } catch {
                notificationManager.show(title: "Failed to encode mock", color: .red)
            }
        }
        notificationManager.show(title: "Request copied to clipboard", color: .green)
    }

    func executeDeeplink() {
        guard let deeplink = DeeplinkStore.shared.deeplinks.last else { return }

        switch deeplink {
        case .openMock(let id, let mockDomain) where self.mockDomain == mockDomain:
            if let mock = mockModelList.first(where: { $0.id == id }) {
                selected = [mock.id]
                DeeplinkStore.shared.deeplinks.removeLast()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NavigationStore.shared.open(.mock(mock))
                }
            }
        default: break
        }
    }
}
