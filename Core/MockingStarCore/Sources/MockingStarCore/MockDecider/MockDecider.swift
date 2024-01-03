//
//  File.swift
//
//
//  Created by Yusuf Özgül on 1.09.2023.
//

import Foundation
import Combine
import CommonKit


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
            logger.fault("Handled request has no url")
            return false
        }

        guard let requestComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.error("Handled request url components failed: \(url)")
            return false
        }

        guard let mockComponents = URLComponents(url: mock.metaData.url, resolvingAgainstBaseURL: false) else {
            logger.error("Mock url components failed: \(mock.metaData.url)")
            return false
        }

        guard mock.metaData.scenario == flags.scenario.orEmpty else {
            logger.info("Requested scenario and mock scenario not matched")
            return false
        }

        let shouldIgnoreQueryConfigs = pathConfigs.contains(where: { $0.executeAllQueries }) && configs.configs.appFilterConfigs.queryFilterDefaultStyleIgnore
        if !shouldIgnoreQueryConfigs {
            var filteredMockQueryList: [URLQueryItem] = []
            var filteredRequestQueryList: [URLQueryItem] = []

            if configs.configs.appFilterConfigs.queryFilterDefaultStyleIgnore {
                logger.debug("Query filter default style ignore")
                filteredMockQueryList = mockComponents.queryItems ?? []
                filteredRequestQueryList = requestComponents.queryItems ?? []
            }

            for queryConfig in queryConfigs {
                if configs.configs.appFilterConfigs.queryFilterDefaultStyleIgnore {
                    if let query = mockComponents.queryItems?.first(where: { $0.name == queryConfig.key }) {
                        if !queryConfig.value.isNilOrEmpty {
                            if queryConfig.value == query.value {
                                filteredMockQueryList.removeAll(where: { $0 == query })
                            }
                        } else {
                            filteredMockQueryList.removeAll(where: { $0 == query })
                        }
                    }

                    if let query = requestComponents.queryItems?.first(where: { $0.name == queryConfig.key }) {
                        if !queryConfig.value.isNilOrEmpty  {
                            if queryConfig.value == query.value {
                                filteredRequestQueryList.removeAll(where: { $0 == query })
                            }
                        } else {
                            filteredRequestQueryList.removeAll(where: { $0 == query })
                        }
                    }

                } else {
                    if let query = mockComponents.queryItems?.first(where: { $0.name == queryConfig.key }) {
                        if !queryConfig.value.isNilOrEmpty {
                            if queryConfig.value == query.value {
                                filteredMockQueryList.append(query)
                            }
                        } else {
                            filteredMockQueryList.append(query)
                        }
                    }

                    if let query = requestComponents.queryItems?.first(where: { $0.name == queryConfig.key }) {
                        if !queryConfig.value.isNilOrEmpty  {
                            if queryConfig.value == query.value {
                                filteredRequestQueryList.append(query)
                            }
                        } else {
                            filteredRequestQueryList.append(query)
                        }
                    }
                }
            }

            guard filteredMockQueryList == filteredRequestQueryList else {
                logger.info("Filtered mock query list and request query list not matched")
                return false
            }
        }

        let shouldIgnoreHeaderConfigs = pathConfigs.contains(where: { $0.executeAllHeaders }) && configs.configs.appFilterConfigs.headerFilterDefaultStyleIgnore
        if !shouldIgnoreHeaderConfigs {
            var filteredMockHeaderList: [String: String] = [:]
            var filteredRequestHeaderList: [String: String] = [:]

            if configs.configs.appFilterConfigs.headerFilterDefaultStyleIgnore {
                logger.debug("Header filter default style ignore")

                filteredMockHeaderList = try mock.requestHeader.asDictionary()
                filteredRequestHeaderList = request.allHTTPHeaderFields ?? [:]
            }

            for headerConfig in headerConfigs {
                if configs.configs.appFilterConfigs.headerFilterDefaultStyleIgnore {
                    if let header = try mock.requestHeader.asDictionary().first(where: { $0.key == headerConfig.key }) {
                        if !headerConfig.value.isNilOrEmpty {
                            if headerConfig.value == header.value {
                                filteredMockHeaderList.removeValue(forKey: header.key)
                            }
                        } else {
                            filteredMockHeaderList.removeValue(forKey: header.key)
                        }
                    }

                    if let header = request.allHTTPHeaderFields?.first(where: { $0.key == headerConfig.key }) {
                        if !headerConfig.value.isNilOrEmpty {
                            if headerConfig.value == header.value {
                                filteredRequestHeaderList.removeValue(forKey: header.key)
                            }
                        } else {
                            filteredRequestHeaderList.removeValue(forKey: header.key)
                        }
                    }
                } else {
                    if let header = try mock.requestHeader.asDictionary().first(where: { $0.key == headerConfig.key }) {
                        if !headerConfig.value.isNilOrEmpty {
                            if headerConfig.value == header.value {
                                filteredMockHeaderList[header.key] = header.value
                            }
                        } else {
                            filteredMockHeaderList[header.key] = ""
                        }
                    }

                    if let header = request.allHTTPHeaderFields?.first(where: { $0.key == headerConfig.key }) {
                        if !headerConfig.value.isNilOrEmpty {
                            if headerConfig.value == header.value {
                                filteredRequestHeaderList[header.key] = header.value
                            }
                        } else {
                            filteredRequestHeaderList[header.key] = ""
                        }
                    }
                }
            }

            guard filteredMockHeaderList == filteredRequestHeaderList else {
                logger.info("Filtered mock header list and request header list not matched")
                return false
            }
        }

        logger.info("Mock Found: \(mock.id)")
        return true
    }
}

extension MockDecider: MockDeciderInterface {
    /// Active state mock filter configurations
    var mockFilters: [MockFilterConfigModel] {
        configs.configs.mockFilterConfigs.filter(\.isActive)
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

        let urlForSearch = try fileUrlBuilder.mocksFolderUrl(for: mockDomain)

        let pathConfigs = configsBuilder.findProperPathConfigs(mockUrl: url,
                                                               pathConfigs: configs.configs.pathConfigs,
                                                               pathMatchingRatio: configs.configs.appFilterConfigs.pathMatchingRatio)
        let queryConfigs = configsBuilder.findProperQueryConfigs(mockUrl: url,
                                                                 queryConfigs: configs.configs.queryConfigs,
                                                                 pathMatchingRatio: configs.configs.appFilterConfigs.pathMatchingRatio)
        let headerConfigs = configsBuilder.findProperHeaderConfigs(mockUrl: url,
                                                                   headers: request.allHTTPHeaderFields ?? [:],
                                                                   headerConfigs: configs.configs.headerConfigs,
                                                                   pathMatchingRatio: configs.configs.appFilterConfigs.pathMatchingRatio)

        var folderContents: [URL] = []

        do {
            folderContents = try fileManager.folderContent(at: fileUrlBuilder.mockListFolderUrl(mocksFolderURL: urlForSearch, requestPath: url.path().encodedUrlPathValue, method: request.httpMethod.orEmpty.uppercased()))
        } catch {
            logger.error("Folder contents error: \(error)")
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
                logger.error("Folder contents error: \(error)")
            }
        }

        logger.info("Decidable mock count: \(folderContents.count) for \(request.url?.absoluteString ?? "")")

        if let scenario = flags.scenario, !scenario.isEmpty {
            guard folderContents.contains(where: { $0.absoluteString.contains(scenario) }) else {
                logger.warning("Scenario not found \(scenario) for: \(request.url?.path() ?? .init())")
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
                logger.critical("Mock can not read, will continue next mock. Error: \(error)")
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

        logger.warning("Mock not found for: \(request.url?.path() ?? .init())")
        return .mockNotFound
    }
}

enum MockDecision: Equatable {
    case useMock(mock: MockModel)
    case mockNotFound
    case scenarioNotFound
}
