//
//  File.swift
//
//
//  Created by Yusuf Özgül on 1.09.2023.
//

import Foundation
import CommonKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol MockDeciderInterface {
    /// Active state mock filter configurations
    var mockFilters: [MockFilterConfigModel] { get }

    /// Mock decider function
    /// - Parameters:
    ///   - request: Mock Server handled request
    ///   - flags: Mock Server flags
    /// - Returns: Final result of ``MockDecision``
    ///
    /// All mocks should be structural file tree, handled request url indicates file location for mock decider should search.
    ///
    /// There are multiple possible location, one for exact path and path configs count.
    /// Because mock can saved before configs.
    func decideMock(request: URLRequest, flags: MockServerFlags) async throws -> MockDecision

    /// The `searchMock` function searches for a mock file that matches the given path, method, and flags.
    /// - Parameters:
    ///   - path: The path of the HTTP request.
    ///   - method: The method of the HTTP request (GET, POST, etc.).
    ///   - flags: Flags indicating mock server configurations and scenarios.
    /// - Returns: The function returns a `MockDecision` enum:
    ///   - `.useMock(mock: MockModel)`: If a matching mock is found, it returns the mock model.
    ///   - `.scenarioNotFound`: If the specified scenario is not found.
    ///   - `.mockNotFound`: If no matching mock is found.
    /// - Throws: Search can throw errors:
    ///   - `FileManagerError`: When there is an error accessing the file system.
    ///   - `JSONDecodingError`: When there is an error decoding JSON data.
    func searchMock(path: String, method: String, flags: MockServerFlags) async throws -> MockDecision
}

/// Find proper mock or fetch original response and save if needed.
///
/// Mock Decider is brain of whole system.
final class MockDecider {
    private let mockDomain: String
    private let fileManager: FileManagerInterface
    private let configs: ConfigurationsInterface
    private let fileUrlBuilder: FileUrlBuilderInterface
    private let configsBuilder: ConfigsBuilderInterface
    private let logger = Logger(category: "MockDecider")

    /// MockDecider initializer
    /// - Parameters:
    ///   - mockDomain: Current mock domain
    ///   - fileUrlBuilder: File url helper for mock files, configuration files and plugin files.
    ///   - configsBuilder: Proper configuration builder for given mock domain and request.
    ///   - fileManager:
    ///   - configs: Current mock domain's configurations
    public init(mockDomain: String,
                fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder(),
                configsBuilder: ConfigsBuilderInterface = ConfigsBuilder(),
                fileManager: FileManagerInterface = FileManager.default,
                configs: ConfigurationsInterface) {
        self.mockDomain = mockDomain
        self.fileUrlBuilder = fileUrlBuilder
        self.configsBuilder = configsBuilder
        self.fileManager = fileManager
        self.configs = configs

        logger.debug("Initialize with \(mockDomain)")
    }

    private func checkMock(request: URLRequest,
                           mock: MockModel,
                           flags: MockServerFlags,
                           pathConfigs: [PathConfigModel],
                           queryConfigs: [QueryConfigModel],
                           headerConfigs: [HeaderConfigModel]) throws -> Bool {
        guard let url = request.url else {
            logger.fault("Handled request has no url", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            return false
        }

        guard let requestComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.error("Handled request url components failed: \(url)", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            return false
        }

        guard let mockComponents = URLComponents(url: mock.metaData.url, resolvingAgainstBaseURL: false) else {
            logger.error("Mock url components failed: \(mock.metaData.url)", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            return false
        }

        guard mock.metaData.scenario == flags.scenario.orEmpty else {
            logger.info("Requested scenario and mock scenario not matched", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            return false
        }

        guard checkQueryItems(url: url.absoluteString, requestComponents: requestComponents, mockComponents: mockComponents, pathConfigs: pathConfigs, queryConfigs: queryConfigs) else {
            logger.info("Filtered mock header list and request header list not matched", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            return false
        }

        guard checkHeaderItems(url: url.absoluteString, requestComponents: request.allHTTPHeaderFields ?? [:], mockComponents: try mock.requestHeader.asDictionary(), pathConfigs: pathConfigs, headerConfigs: headerConfigs) else {
            logger.info("Filtered mock header list and request header list not matched", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            return false
        }

        logger.info("Mock Found: \(mock.id)", metadata: [
            "traceUrl": .string(request.url?.absoluteString ?? "")
        ])
        return true
    }

    private func checkQueryItems(url: String, requestComponents: URLComponents, mockComponents: URLComponents, pathConfigs: [PathConfigModel], queryConfigs: [QueryConfigModel]) -> Bool {
        let mockQueryList: [URLQueryItem]
        let requestQueryList: [URLQueryItem]

        let queryExecuteStyle = pathConfigs.first?.queryExecuteStyle ?? configs.configs.appFilterConfigs.queryExecuteStyle
        logger.info("Query execute style is \(queryExecuteStyle)", metadata: [
            "traceUrl": .string(url)
        ])

        switch queryExecuteStyle {
        /// Ignore all queries, only select config query list
        case .ignoreAll:
            mockQueryList = mockComponents.queryItems?.filter { query in
                queryConfigs.contains(where: { $0.key == query.name && $0.value.isNilOrEmpty ? true : $0.value.orEmpty == query.value })
            } ?? []
            requestQueryList = requestComponents.queryItems?.filter { query in
                queryConfigs.contains(where: { $0.key == query.name && $0.value.isNilOrEmpty ? true : $0.value.orEmpty == query.value })
            } ?? []

        /// Match all queries, only ignore config query list
        case .matchAll:
            var allMockQueryItems = mockComponents.queryItems ?? []
            allMockQueryItems.removeAll { query in
                queryConfigs.contains(where: { $0.key == query.name && $0.value.isNilOrEmpty ? true : $0.value.orEmpty == query.value })
            }

            var allRequestQueryItems = requestComponents.queryItems ?? []
            allRequestQueryItems.removeAll { query in
                queryConfigs.contains(where: { $0.key == query.name && $0.value.isNilOrEmpty ? true : $0.value.orEmpty == query.value })
            }

            mockQueryList = allMockQueryItems
            requestQueryList = allRequestQueryItems
        }

        logger.info("All queries filtered and mock: \(mockQueryList.count) - request: \(requestQueryList.count)", metadata: [
            "traceUrl": .string(url)
        ])
        return mockQueryList == requestQueryList
    }

    private func checkHeaderItems(url: String, requestComponents: [String:String], mockComponents: [String:String], pathConfigs: [PathConfigModel], headerConfigs: [HeaderConfigModel]) -> Bool {
        let mockHeaders: [String:String]
        let requestHeaders: [String:String]

        let headerExecuteStyle = pathConfigs.first?.headerExecuteStyle ?? configs.configs.appFilterConfigs.headerExecuteStyle
        logger.info("Header execute style is: \(headerExecuteStyle)", metadata: [
            "traceUrl": .string(url)
        ])

        switch headerExecuteStyle {
        /// Ignore all queries, only select config query list
        case .ignoreAll:
            mockHeaders = mockComponents.filter { header in
                headerConfigs.contains(where: { $0.key == header.key && $0.value.isNilOrEmpty ? true : $0.value.orEmpty == header.value })
            }

            requestHeaders = requestComponents.filter { header in
                headerConfigs.contains(where: { $0.key == header.key && $0.value.isNilOrEmpty ? true : $0.value.orEmpty == header.value })
            }
        /// Match all queries, only ignore config query list
        case .matchAll:
            var allMockHeaderItems = mockComponents
            allMockHeaderItems.forEach { header in
                if headerConfigs.contains(where: { $0.key == header.key && $0.value.isNilOrEmpty ? true : $0.value.orEmpty == header.value }) {
                    allMockHeaderItems.removeValue(forKey: header.key)
                }
            }

            var allRequestHeaderItems = requestComponents
            allRequestHeaderItems.forEach { header in
                if headerConfigs.contains(where: { $0.key == header.key && $0.value.isNilOrEmpty ? true : $0.value.orEmpty == header.value }) {
                    allRequestHeaderItems.removeValue(forKey: header.key)
                }
            }

            mockHeaders = allMockHeaderItems
            requestHeaders = allRequestHeaderItems
        }

        logger.info("All headers filtered and mock: \(mockHeaders.count) - request: \(requestHeaders.count)", metadata: [
            "traceUrl": .string(url)
        ])
        return mockHeaders == requestHeaders
    }

    /// Determines should search mock for this domain. Based on configuration.
    /// If configuration is empty, default behaviours is search.
    /// When checking subdomains, the root domain variation should also be checked
    /// - Parameter domain: Current request hostname
    /// - Returns: Ignore or not searching mocks for this domain.
    private func shouldSearchMocks(for domain: String) -> Bool {
        let configDomains = configs.configs.appFilterConfigs.domains
        guard !configDomains.isEmpty else { return true }

        var requestDomains: [String] = []

        for index in 0..<domain.components(separatedBy: ".").dropLast().count {
            requestDomains.append(domain.components(separatedBy: ".").dropFirst(index).joined(separator: "."))
        }

        return configDomains.contains(where: { requestDomains.contains($0) })
    }
}

extension MockDecider: MockDeciderInterface {
    /// Active state mock filter configurations
    var mockFilters: [MockFilterConfigModel] {
        configs.configs.mockFilterConfigs
    }

    /// Decides the appropriate mock response for a given URLRequest based on mock data.
    ///
    /// This function performs the following steps:
    /// 1. Extracts the URL from the provided URLRequest.
    /// 2. Finds path, query, and header configurations based on the request.
    /// 3. Retrieves the list of mock files within the corresponding mockListFolder.
    /// 4. Optionally filters the mock files based on a specified scenario.
    /// 5. Iterates through the filtered list of mock files, attempting to read and match each mock.
    /// 6. Returns the decision to use a matched mock or indicates that no suitable mock was found.
    ///
    /// - Parameters:
    ///   - request: The URLRequest for which a mock decision is made.
    ///   - flags: Additional flags to control the mock decision process.
    /// - Returns: A `MockDecision` representing the decision to use a mock or indicating that no suitable mock was found.
    /// - Throws: If any error occurs during the mock decision process, it is thrown.
    func decideMock(request: URLRequest, flags: MockServerFlags) async throws -> MockDecision {
        guard let url = request.url else { return .mockNotFound }
        guard shouldSearchMocks(for: url.host().orEmpty) else { return .ignoreDomain }

        let urlForSearch = try fileUrlBuilder.mocksFolderUrl(for: mockDomain)

        let pathConfigs = configsBuilder.findProperPathConfigs(mockUrl: url,
                                                               pathConfigs: configs.configs.pathConfigs,
                                                               pathMatchingRatio: configs.configs.appFilterConfigs.pathMatchingRatio)
        let queryConfigs = configsBuilder.findProperQueryConfigs(mockUrl: url,
                                                                 queryConfigs: configs.configs.queryConfigs,
                                                                 appFilterConfigs: configs.configs.appFilterConfigs)
        let headerConfigs = configsBuilder.findProperHeaderConfigs(mockUrl: url,
                                                                   headers: request.allHTTPHeaderFields ?? [:],
                                                                   headerConfigs: configs.configs.headerConfigs,
                                                                   appFilterConfigs: configs.configs.appFilterConfigs)

        var folderContents: [URL] = []

        do {
            folderContents = try fileManager.folderContent(at: fileUrlBuilder.mockListFolderUrl(mocksFolderURL: urlForSearch, requestPath: url.path().encodedUrlPathValue, method: request.httpMethod.orEmpty.uppercased()))
        } catch {
            logger.error("Folder contents error: \(error)", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
        }

        pathConfigs.forEach { config in
            do {
                let folderPath = try fileUrlBuilder.mockListConfiguredUrl(mocksFolderURL: urlForSearch,
                                                                          requestPath: url.path(),
                                                                          configPath: config.path,
                                                                          method: request.httpMethod.orEmpty.uppercased())
                let contents = try fileManager.folderContent(at: folderPath)
                folderContents.append(contentsOf: contents)
            } catch {
                logger.error("Folder contents error: \(error)", metadata: [
                    "traceUrl": .string(request.url?.absoluteString ?? "")
                ])
            }
        }

        logger.info("Decidable mock count: \(folderContents.count)", metadata: [
            "traceUrl": .string(request.url?.absoluteString ?? "")
        ])

        if let scenario = flags.scenario, !scenario.isEmpty {
            guard folderContents.contains(where: { $0.absoluteString.contains(scenario) }) else {
                logger.warning("Scenario not found \(scenario) for: \(request.url?.path() ?? .init())", metadata: [
                    "traceUrl": .string(request.url?.absoluteString ?? "")
                ])
                return .scenarioNotFound
            }

            folderContents.sort(by: { url1, url2 in
                url1.absoluteString.contains(scenario)
            })
        }

        for url in folderContents {
            let mock: MockModel

            do {
                mock = try fileManager.readJSONFile(at: url)
            } catch {
                logger.critical("Mock can not read, will continue next mock. Error: \(error)", metadata: [
                    "traceUrl": .string(request.url?.absoluteString ?? "")
                ])
                continue
            }

            if try checkMock(request: request,
                             mock: mock,
                             flags: flags,
                             pathConfigs: pathConfigs,
                             queryConfigs: queryConfigs,
                             headerConfigs: headerConfigs) {
                return .useMock(mock: mock)
            }
        }

        logger.warning("Mock not found for: \(request.url?.path() ?? .init())", metadata: [
            "traceUrl": .string(request.url?.absoluteString ?? "")
        ])
        return .mockNotFound
    }
    
    /// The `searchMock` function searches for a mock file that matches the given path, method, and flags.
    /// - Parameters:
    ///   - path: The path of the HTTP request.
    ///   - method: The method of the HTTP request (GET, POST, etc.).
    ///   - flags: Flags indicating mock server configurations and scenarios.
    /// - Returns: The function returns a `MockDecision` enum:
    ///   - `.useMock(mock: MockModel)`: If a matching mock is found, it returns the mock model.
    ///   - `.scenarioNotFound`: If the specified scenario is not found.
    ///   - `.mockNotFound`: If no matching mock is found.
    /// - Throws: Search can throw errors:
    ///   - `FileManagerError`: When there is an error accessing the file system.
    ///   - `JSONDecodingError`: When there is an error decoding JSON data.
    func searchMock(path: String, method: String, flags: MockServerFlags) async throws -> MockDecision {
        let urlForSearch = try fileUrlBuilder.mocksFolderUrl(for: mockDomain)
        var folderContents: [URL] = []

        do {
            folderContents = try fileManager.folderContent(at: fileUrlBuilder.mockListFolderUrl(mocksFolderURL: urlForSearch, requestPath: path.encodedUrlPathValue, method: method.uppercased()))
        } catch {
            logger.error("Folder contents error: \(error)", metadata: [
                "traceUrl": .string(path)
            ])
        }

        logger.info("Search decidable mock count: \(folderContents.count) for \(path)", metadata: [
            "traceUrl": .string(path)
        ])

        if let scenario = flags.scenario, !scenario.isEmpty {
            guard folderContents.contains(where: { $0.absoluteString.contains(scenario) }) else {
                logger.warning("Scenario not found \(scenario) for: \(path)", metadata: [
                    "traceUrl": .string(path)
                ])
                return .scenarioNotFound
            }

            folderContents.sort(by: { url1, url2 in
                url1.absoluteString.contains(scenario)
            })
        }

        for url in folderContents {
            let mock: MockModel

            do {
                mock = try fileManager.readJSONFile(at: url)
            } catch {
                logger.critical("Mock can not read, will continue next mock. Error: \(error)", metadata: [
                    "traceUrl": .string(path)
                ])
                continue
            }

            guard mock.metaData.scenario == flags.scenario.orEmpty else {
                logger.info("Requested scenario and mock scenario not matched", metadata: [
                    "traceUrl": .string(path)
                ])
                continue
            }

            return .useMock(mock: mock)
        }

        logger.warning("Mock not found for: \(path)", metadata: [
            "traceUrl": .string(path)
        ])
        return .mockNotFound
    }
}

enum MockDecision: Equatable {
    case useMock(mock: MockModel)
    case mockNotFound
    case scenarioNotFound
    case ignoreDomain
}
