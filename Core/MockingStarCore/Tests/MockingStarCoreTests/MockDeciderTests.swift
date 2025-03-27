//
//  MockDeciderTests.swift
//
//
//  Created by Yusuf Özgül on 4.09.2023.
//

import XCTest
import CommonKit
import CommonKitTestSupport
@testable import MockingStarCore

final class MockDeciderTests: XCTestCase {
    private var decider: MockDecider!
    private var fileUrlBuilder: MockFileUrlBuilder!
    private var configsBuilder: MockConfigsBuilder!
    private var fileManager: MockFileManager!
    private var configs: MockConfigurations!

    override func setUpWithError() throws {
        try super.setUpWithError()

        fileUrlBuilder = .init()
        configsBuilder = .init()
        fileManager = .init()
        configs = .init()
        decider = .init(mockDomain: "LocalDevelopment",
                        fileUrlBuilder: fileUrlBuilder,
                        configsBuilder: configsBuilder,
                        fileManager: fileManager,
                        configs: configs)

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))

        fileManager.stubbedFolderContentResult = [
            URL(string: "foo"),
            URL(string: "bar"),
        ].compactMap { $0 }

        fileManager.stubbedReadJSONFileResult = MockModel(metaData: .init(url: url,
                                                                          method: "GET",
                                                                          appendTime: .init(),
                                                                          updateTime: .init(),
                                                                          httpStatus: 200,
                                                                          responseTime: 0.15,
                                                                          scenario: "",
                                                                          id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                                                          requestHeader: "{}",
                                                          responseHeader: "{}",
                                                          requestBody: .init(""),
                                                          responseBody: .init(""))
        fileUrlBuilder.stubbedMocksFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        configs.stubbedConfigs = .init(pathConfigs: [],
                                       queryConfigs: [],
                                       headerConfigs: [],
                                       mockFilterConfigs: [],
                                       appFilterConfigs: .init())
        configsBuilder.stubbedFindProperPathConfigsResult = []
        configsBuilder.stubbedFindProperQueryConfigsResult = []
        configsBuilder.stubbedFindProperHeaderConfigsResult = []
    }

    private func request(url: String = "https://www.trendyol.com/aboutus", query: [URLQueryItem] = [], headers: [String: String] = [:]) throws -> URLRequest {
        var url = try XCTUnwrap(URL(string: url))
        url.append(queryItems: query)

        var request = URLRequest(url: url)
        headers.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    func test_decideMock_ScenarioNotMatched() async throws {
        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "EmptyResponse",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(),
                                                  flags: flags)

        XCTAssertEqual(result, .scenarioNotFound)
    }

    func test_decideMock_ScenarioMatched() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [
            URL(string: "stubbedMocksFolderUrlResult-EmptyResponse"),
        ].compactMap { $0 }
        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "EmptyResponse",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "EmptyResponse",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_ScenarioMatchedOnlyFileName() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [
            URL(string: "stubbedMocksFolderUrlResult-EmptyResponse"),
        ].compactMap { $0 }
        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "EmptyResponse",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(),
                                                  flags: flags)

        XCTAssertEqual(result, .mockNotFound)
    }

    func test_decideMock_QueryDefaultIgnore_ExecuteAllQuery() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.queryExecuteStyle = .ignoreAll
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .ignoreAll, headerExecuteStyle: .ignoreAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us?device=ios"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "device", value: "android")]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_QueryDefaultIgnore_WithQueryConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.queryExecuteStyle = .ignoreAll
        configsBuilder.stubbedFindProperQueryConfigsResult = [.init(key: "userId")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .ignoreAll, headerExecuteStyle: .ignoreAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us?userId=1&device=ios"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "userId", value: "1"),
                                                                           .init(name: "device", value: "android")]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_QueryDefaultIgnore_WithQueryConfig_NotMatched() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.queryExecuteStyle = .ignoreAll
        configsBuilder.stubbedFindProperQueryConfigsResult = [.init(key: "userId", value: "1")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .ignoreAll, headerExecuteStyle: .ignoreAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us?userId=1&device=ios"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "userId", value: "2"),
                                                                           .init(name: "device", value: "android")]),
                                                  flags: flags)

        XCTAssertEqual(result, .mockNotFound)
    }

    func test_decideMock_QueryDefaultIgnore_WithoutQueryConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.queryExecuteStyle = .ignoreAll
        configsBuilder.stubbedFindProperQueryConfigsResult = []
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .ignoreAll, headerExecuteStyle: .ignoreAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us?device=ios"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "device", value: "android")]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_QueryDefaultNotIgnore_WithQueryConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.queryExecuteStyle = .matchAll
        configsBuilder.stubbedFindProperQueryConfigsResult = [.init(key: "device")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .matchAll, headerExecuteStyle: .ignoreAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us?device=ios"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "device", value: "android")]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_QueryDefaultNotIgnore_WithQueryConfig_NotMatched() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.queryExecuteStyle = .matchAll
        configsBuilder.stubbedFindProperQueryConfigsResult = [.init(key: "device", value: "ios")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .matchAll, headerExecuteStyle: .ignoreAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us?device=ios"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "device", value: "android")]),
                                                  flags: flags)

        XCTAssertEqual(result, .mockNotFound)
    }

    func test_decideMock_HeaderDefaultIgnore_ExecuteAllHeader() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerExecuteStyle = .ignoreAll
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .ignoreAll, headerExecuteStyle: .ignoreAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: """
                           {
                              "device": "ios",
                              "version": "1.2.3"
                           }
                           """,
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "device": "android",
            "version": "1.2.2"
        ]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_HeaderDefaultIgnore_WithHeaderConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerExecuteStyle = .ignoreAll
        configsBuilder.stubbedFindProperHeaderConfigsResult = [.init(key: "userId")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .ignoreAll, headerExecuteStyle: .ignoreAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: """
                           {
                              "userId": "1",
                              "device": "ios",
                              "version": "1.2.3"
                           }
                           """,
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "userId": "1",
            "device": "android",
            "version": "1.2.2"
        ]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_HeaderDefaultIgnore_WithoutHeaderConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerExecuteStyle = .ignoreAll
        configsBuilder.stubbedFindProperHeaderConfigsResult = []
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .ignoreAll, headerExecuteStyle: .ignoreAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: """
                           {
                              "device": "ios",
                              "version": "1.2.3"
                           }
                           """,
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "device": "android",
            "version": "1.2.2"
        ]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_HeaderDefaultNotIgnore_WithHeaderConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerExecuteStyle = .matchAll
        configsBuilder.stubbedFindProperHeaderConfigsResult = [.init(key: "device")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .ignoreAll, headerExecuteStyle: .matchAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: """
                           {
                              "device": "ios",
                              "version": "1.2.3"
                           }
                           """,
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "device": "android",
            "version": "1.2.3"
        ]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_HeaderDefaultNotIgnore_WithHeaderConfig_OnlyKeyHeader() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerExecuteStyle = .matchAll
        configsBuilder.stubbedFindProperHeaderConfigsResult = [.init(key: "device", value: "ios")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .ignoreAll, headerExecuteStyle: .matchAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: """
                           {
                              "device": "ios",
                              "version": "1.2.3"
                           }
                           """,
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "device": "android",
            "version": "1.2.2"
        ]),
                                                  flags: flags)

        XCTAssertEqual(result, .mockNotFound)
    }

    func test_decideMock_HeaderDefaultNotIgnore_WithHeaderConfig_NotMatched() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerExecuteStyle = .matchAll
        configsBuilder.stubbedFindProperHeaderConfigsResult = [.init(key: "device", value: "ios")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/about-us", queryExecuteStyle: .ignoreAll, headerExecuteStyle: .matchAll)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/about-us"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: """
                           {
                              "device": "ios",
                              "version": "1.2.3"
                           }
                           """,
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "device": "android",
            "version": "1.2.2"
        ]),
                                                  flags: flags)

        XCTAssertEqual(result, .mockNotFound)
    }

    func test_decideMock_IgnoreDomain() async throws {
        configs.stubbedConfigs.appFilterConfigs.domains = ["github.com"]

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "EmptyResponse",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(),
                                                  flags: flags)

        XCTAssertEqual(result, .ignoreDomain)
    }

    func test_decideMock_NotIgnoreDomain_ScenarioMatched() async throws {
        configs.stubbedConfigs.appFilterConfigs.domains = ["trendyol.com"]
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [
            URL(string: "stubbedMocksFolderUrlResult-EmptyResponse"),
        ].compactMap { $0 }
        let url = try XCTUnwrap(URL(string: "https://trendyol.com/aboutus"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "EmptyResponse",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "EmptyResponse",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_NotIgnoreDomain_WithSubdomain_ScenarioMatched() async throws {
        configs.stubbedConfigs.appFilterConfigs.domains = ["trendyol.com"]
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [
            URL(string: "stubbedMocksFolderUrlResult-EmptyResponse"),
        ].compactMap { $0 }
        let url = try XCTUnwrap(URL(string: "https://subdomain.trendyol.com/aboutus"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "EmptyResponse",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "EmptyResponse",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_searchMock_ReturnMock() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [
            URL(string: "stubbedMocksFolderUrlResult-EmptyResponse"),
        ].compactMap { $0 }
        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "EmptyResponse",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "EmptyResponse",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.searchMock(path: "/aboutus",
                                                  method: "GET",
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_searchMock_ScenarioNotMatched() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [
            URL(string: "stubbedMocksFolderUrlResult-ErrorResponse"),
        ].compactMap { $0 }
        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "ErrorResponse",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "EmptyResponse",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.searchMock(path: "/aboutus",
                                                  method: "GET",
                                                  flags: flags)

        XCTAssertEqual(result, .scenarioNotFound)
    }

    func test_searchMock_ScenarioNotMatched_EmptyMocks() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = []
        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))
        let mock = MockModel(metaData: .init(url: url,
                                             method: "GET",
                                             appendTime: .init(),
                                             updateTime: .init(),
                                             httpStatus: 200,
                                             responseTime: 0.15,
                                             scenario: "ErrorResponse",
                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                             requestHeader: "{}",
                             responseHeader: "{}",
                             requestBody: .init(""),
                             responseBody: .init(""))
        fileManager.stubbedReadJSONFileResult = mock

        XCTAssertFalse(fileManager.invokedFolderContent)
        XCTAssertFalse(fileUrlBuilder.invokedMockListFolderUrl)
        XCTAssertFalse(configsBuilder.invokedFindProperPathConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperQueryConfigs)
        XCTAssertFalse(configsBuilder.invokedFindProperHeaderConfigs)

        let flags: MockServerFlags = .init(mockSource: .default,
                                           scenario: "ErrorResponse",
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.searchMock(path: "/aboutus",
                                                  method: "GET",
                                                  flags: flags)

        XCTAssertEqual(result, .scenarioNotFound)
    }
}
