//
//  MockListViewModel.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 21.09.2023.
//

import CommonKit
import SwiftUI
import MockingStarCore
import Combine

@Observable
public final class MockListViewModel {
    private let fileManager: FileManagerInterface
    private var cancelableSet = Set<AnyCancellable>()
    private let mockDiscover: MockDiscoverInterface

    private var listSortTask: Task<(), Never>? = nil
    var sortOrder = [KeyPathComparator(\MockModel.metaData.updateTime, order: .forward)]
    var filterType: FilterType = .all
    var filterStyle: FilterStyle = .contains
    var searchTerm: String = ""
    var shouldShowDeleteConfirmation: Bool = false
    var selected = Set<MockModel.ID>()

    // MARK: Error
    var shouldShowErrorMessage = false
    var errorMessage: String = ""
    
    // MARK: Mock List
    private(set) var mockModelList: [MockModel] = []
    private(set) var mockListUIModel: [MockModel] = []

    public init(fileManager: FileManagerInterface = FileManager.default,
                mockDiscover: MockDiscoverInterface = MockDiscover()) {
        self.fileManager = fileManager
        self.mockDiscover = mockDiscover
        listenMockDiscover()
    }

    private func listenMockDiscover() {
        mockDiscover.mockListSubject
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] mocks in
                self?.mockModelList = Array(mocks)
            }
            .store(in: &cancelableSet)
    }
    
    /// Searches and filters mock data based on the specified search term, filter type, and filter style.
    ///
    /// This asynchronous function performs a case-insensitive search on the mock model list based on the specified search term. It filters the mocks based on the selected filter type, filter style, and the specified conditions.
    func searchData() async {
        let searchTerm = searchTerm.lowercased()
        
        guard !searchTerm.isEmpty else {
            await MainActor.run {
                mockListUIModel = mockModelList.sorted(using: sortOrder)
            }
            return
        }
        
        let filteredMocks = mockModelList.filter {
            let filterFields: [String] = switch filterType {
            case .all: [$0.metaData.url.path(), $0.metaData.url.query(), $0.metaData.scenario, $0.metaData.method].compactMap { $0 }
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
        
        await MainActor.run {
            mockListUIModel = filteredMocks.sorted(using: sortOrder)
        }
    }
    
    func mock(id: String) -> MockModel? {
        mockModelList.first(where: { $0.id == id })
    }
    
    func deleteSelectedMocks() {
        for select in selected {
            guard let mock = mock(id: select), let filePath = mock.fileURL?.path(percentEncoded: false) else { return }
            
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
    func mockDomainChanged(_ domain: String) async {
        do {
            try await mockDiscover.updateMockDomain(domain)
        } catch {
            guard !(error is CancellationError) else { return }
            print("Mock Domain Changed Error: \(error)")
        }
    }
}
