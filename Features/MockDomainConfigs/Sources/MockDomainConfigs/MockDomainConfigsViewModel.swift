//
//  MockDomainConfigsViewModel.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import CommonKit
import CommonViewsKit
import Foundation
import SwiftUI
import MockingStarCore

@Observable
public final class MockDomainConfigsViewModel {
    private let logger = Logger(category: "MockDomainConfigsViewModel")
    private let notificationManager: NotificationManagerInterface
    private let mockDiscover: MockDiscoverInterface

    // MARK: UI Models
    var appFilterConfigs = AppFilterConfigs()
    var mocksFilters: [MockFilterConfigs] = []
    var pathConfigs: [MockPathConfigModel] = []
    var queryConfigs: [MockQueryConfigModel] = []
    var headerConfigs: [MockHeaderConfigModel] = []
    
    private(set) var allPaths: [String] = []

    private var configs: ConfigModel = ConfigModel()
    private let fileManager: FileManagerInterface
    private let fileUrlBuilder: FileUrlBuilderInterface
    private var fileStructureMonitor: FileStructureMonitorInterface
    private var mockDomain: String = ""
    private var isFileMonitorStarted: Bool = false

    public init(fileManager: FileManagerInterface = FileManager.default,
                fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder(),
                fileStructureMonitor: FileStructureMonitorInterface = FileStructureMonitor(),
                notificationManager: NotificationManagerInterface = NotificationManager.shared,
                mockDiscover: MockDiscoverInterface = MockDiscover()) {
        self.fileUrlBuilder = fileUrlBuilder
        self.fileManager = fileManager
        self.fileStructureMonitor = fileStructureMonitor
        self.notificationManager = notificationManager
        self.mockDiscover = mockDiscover
        
        listenMockDiscover()
    }

    private func watchConfigs() {
        guard !isFileMonitorStarted else { return }
        isFileMonitorStarted = true
        do {
            fileStructureMonitor.stop()
            let url = try fileUrlBuilder.configsFolderUrl(for: mockDomain)
            try fileStructureMonitor.startMonitoring(url: url)

            fileStructureMonitor.changeHandler = { [weak self] event in
                guard let self, case .configChange = event else { return }
                
                do {
                    try readConfigs()
                } catch {
                    logger.error("Read configs error: \(error)")
                }
            }
        } catch {
            logger.error("Watch configs error: \(error)")
            return
        }
    }

    /// Updates the mock domain and triggers the process of reading and saving configurations.
    ///
    /// - Parameters:
    ///   - mockDomain: The new mock domain to be set.
    func mockDomainUpdated(mockDomain: String) {
        guard self.mockDomain != mockDomain else { return }
        self.mockDomain = mockDomain
        isFileMonitorStarted = false

        do {
            try readConfigs()
        } catch {
            logger.error("Read configs error: \(error)")
        }

        Task { try await mockDiscover.updateMockDomain(mockDomain) }
    }

    /// Saves the changes made to the configurations.
    func saveChanges() {
        do {
            let url = try fileUrlBuilder.configUrl(for: mockDomain)
            let updatedConfigs = ConfigModel(pathConfigs: pathConfigs.map { $0.asPathConfigModel() },
                                             queryConfigs: queryConfigs.map { $0.asQueryConfigModel() },
                                             headerConfigs: headerConfigs.map { $0.asHeaderConfigModel() },
                                             mockFilterConfigs: mocksFilters.map { $0.asMockFilterConfigModel() },
                                             appFilterConfigs: appFilterConfigs.asAppConfigModel())

            guard updatedConfigs != configs else { return }

            try fileManager.updateFileContent(path: url.path(), content: updatedConfigs)
            configs = updatedConfigs
            notificationManager.show(title: "All changes saved", color: .green)
        } catch {
            logger.error("Save configs error: \(error)")
            notificationManager.show(title: "Save configs error: \(error)", color: .red)
        }
    }

    func queryExecuteStyle(for path: String) -> QueryExecuteStyle {
        pathConfigs
            .first(where: { fileUrlBuilder.isPathMatched(requestPath: path,
                                                         configPath: $0.path,
                                                         pathMatchingRatio: appFilterConfigs.pathMatchingRatio) })?
            .queryExecuteStyle ?? appFilterConfigs.queryExecuteStyle
    }

    func headerExecuteStyle(for path: String) -> HeaderExecuteStyle {
        pathConfigs
            .first(where: { fileUrlBuilder.isPathMatched(requestPath: path,
                                                         configPath: $0.path,
                                                         pathMatchingRatio: appFilterConfigs.pathMatchingRatio) })?
            .headerExecuteStyle ?? appFilterConfigs.headerExecuteStyle
    }

    /// Reads configurations from the file.
    private func readConfigs() throws {
        let url = try fileUrlBuilder.configUrl(for: mockDomain)
        let configs: ConfigModel

        do {
            configs = try fileManager.readJSONFile(at: url)
            watchConfigs()
        } catch FileManagerError.fileNotFound {
            configs = ConfigModel()
            let folderPath = try fileUrlBuilder.configsFolderUrl(for: mockDomain)
            try fileManager.write(to: folderPath, fileName: url.lastPathComponent, model: configs)
            watchConfigs()
        } catch {
            throw error
        }

        guard self.configs != configs else { return }

        self.configs = configs
        appFilterConfigs = .init(appFilterConfigs: configs.appFilterConfigs)
        mocksFilters = configs.mockFilterConfigs.map { .init(mockFilterConfig: $0) }
        pathConfigs = configs.pathConfigs.map { .init(pathConfig: $0) }
        queryConfigs = configs.queryConfigs.map { .init(queryConfig: $0) }
        headerConfigs = configs.headerConfigs.map { .init(headerConfig: $0) }
        migrateFilterLogicTypes()
    }

    private func migrateFilterLogicTypes() {
        guard !mocksFilters.isEmpty else { return }
        
        for (index, filter) in mocksFilters.enumerated() {
            if index == mocksFilters.count - 1 {
                if filter.logicType.isOperator {
                    filter.logicType = .mock
                }
            } else {
                if filter.logicType.isAction {
                    filter.logicType = .or
                }
            }
        }
    }
    
    func addNewFilter() {
        withMutation(keyPath: \.mocksFilters) {
            if let lastFilter = mocksFilters.last {
                if lastFilter.logicType.isAction {
                    lastFilter.logicType = .or
                }
            }
            
            mocksFilters.append(.init(inputText: "", logicType: .mock))
        }
    }
    
    func removeFilter(id: UUID) {
        withMutation(keyPath: \.mocksFilters) {
            mocksFilters.removeAll(where: { $0.id == id })
            migrateFilterLogicTypes()
        }
    }
    
    func moveFilter(from source: IndexSet, to destination: Int) {
        withMutation(keyPath: \.mocksFilters) {
            mocksFilters.move(fromOffsets: source, toOffset: destination)
            migrateFilterLogicTypes()
        }
    }
    
    private func listenMockDiscover() {
        Task {
            for await result in mockDiscover.mockDiscoverResult {
                switch result {
                case .loading:
                    break
                case .result(let mocks):
                    let allPaths = mocks.compactMap { $0.metaData.url.path() }
                    self.allPaths = Array(Set(allPaths))
                }
            }
        }
    }
}
