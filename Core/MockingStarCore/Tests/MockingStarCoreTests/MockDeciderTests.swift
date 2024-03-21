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
                                           shouldNotMock: false,
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
                                           shouldNotMock: false,
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
                                           shouldNotMock: false,
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
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = true
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/aboutus", executeAllQueries: true, executeAllHeaders: false)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus?id=10&useNewDesign=false&gender=F"))
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "id", value: "10"),
                                                                           .init(name: "useNewDesign", value: "true"),
                                                                           .init(name: "gender", value: "F"),]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_QueryDefaultIgnore_WithQueryConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = true
        configsBuilder.stubbedFindProperQueryConfigsResult = [.init(key: "id"), .init(key: "gender", value: "F")]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus?id=20&useNewDesign=true&gender=F"))
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "id", value: "10"),
                                                                           .init(name: "useNewDesign", value: "true"),
                                                                           .init(name: "gender", value: "F"),]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_QueryDefaultIgnore_WithQueryConfig_NotMatched() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = true
        configsBuilder.stubbedFindProperQueryConfigsResult = [.init(key: "id"), .init(key: "gender", value: "F")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/aboutus", executeAllQueries: false, executeAllHeaders: false)]
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus?id=20&useNewDesign=true&gender=F"))
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "id", value: "10"),
                                                                           .init(name: "useNewDesign", value: "false"),
                                                                           .init(name: "gender", value: "F"),]),
                                                  flags: flags)

        XCTAssertEqual(result, .mockNotFound)
    }

    func test_decideMock_QueryDefaultIgnore_WithoutQueryConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = true
        configsBuilder.stubbedFindProperQueryConfigsResult = []

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus?id=20&useNewDesign=true&gender=F"))
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "id", value: "10"),
                                                                           .init(name: "useNewDesign", value: "true"),
                                                                           .init(name: "gender", value: "F"),]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_QueryDefaultNotIgnore_WithQueryConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = false
        configsBuilder.stubbedFindProperQueryConfigsResult = [.init(key: "useNewDesign", value: "true")]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus?id=20&useNewDesign=true&gender=F"))
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "id", value: "10"),
                                                                           .init(name: "useNewDesign", value: "true"),
                                                                           .init(name: "gender", value: "F"),]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_QueryDefaultNotIgnore_WithQueryConfig_NotMatched() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = false
        configsBuilder.stubbedFindProperQueryConfigsResult = [.init(key: "useNewDesign", value: "true"), .init(key: "id")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/aboutus", executeAllQueries: false, executeAllHeaders: false)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus?id=20&useNewDesign=true&gender=F"))
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(query: [.init(name: "id", value: "10"),
                                                                           .init(name: "useNewDesign", value: "true"),
                                                                           .init(name: "gender", value: "F"),]),
                                                  flags: flags)

        XCTAssertEqual(result, .mockNotFound)
    }

    func test_decideMock_HeaderDefaultIgnore_ExecuteAllHeader() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerFilterDefaultStyleIgnore = true
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = true
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/aboutus", executeAllQueries: true, executeAllHeaders: true)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus?id=10&useNewDesign=false&gender=F"))
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
                                "platform": "iPhone",
                                "version": "1.2.3",
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "platform": "iPhone",
            "version": "1.2.2",
        ]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_HeaderDefaultIgnore_WithHeaderConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerFilterDefaultStyleIgnore = true
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = true
        configsBuilder.stubbedFindProperHeaderConfigsResult = [.init(key: "version"), .init(key: "platform", value: "iPhone")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/aboutus", executeAllQueries: true, executeAllHeaders: false)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus?id=20&useNewDesign=true&gender=F"))
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
                                "platform": "iPhone",
                                "version": "1.2.3",
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "platform": "iPhone",
            "version": "1.2.2",
        ]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_HeaderDefaultIgnore_WithoutHeaderConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerFilterDefaultStyleIgnore = true
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = true
        configsBuilder.stubbedFindProperHeaderConfigsResult = []
        configsBuilder.stubbedFindProperPathConfigsResult = []

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))
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
                                "platform": "android",
                                "version": "1.2.3",
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "platform": "iPhone",
            "version": "1.2.2",
        ]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_HeaderDefaultNotIgnore_WithHeaderConfig() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerFilterDefaultStyleIgnore = false
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = true
        configsBuilder.stubbedFindProperHeaderConfigsResult = [.init(key: "platform", value: "iPhone")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/aboutus", executeAllQueries: true, executeAllHeaders: true)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus?id=20&useNewDesign=true&gender=F"))
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
                                "platform": "iPhone",
                                "version": "1.2.3",
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "platform": "iPhone",
            "version": "1.2.2",
        ]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_HeaderDefaultNotIgnore_WithHeaderConfig_OnlyKeyHeader() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerFilterDefaultStyleIgnore = false
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = true
        configsBuilder.stubbedFindProperHeaderConfigsResult = [.init(key: "platform")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/aboutus", executeAllQueries: true, executeAllHeaders: true)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus?id=20&useNewDesign=true&gender=F"))
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
                                "platform": "iPhone",
                                "version": "1.2.3",
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "platform": "iPhone",
            "version": "1.2.2",
        ]),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }

    func test_decideMock_HeaderDefaultNotIgnore_WithHeaderConfig_NotMatched() async throws {
        fileUrlBuilder.stubbedMockListFolderUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileUrlBuilder.stubbedMockListConfiguredUrlResult = URL(string: "stubbedMocksFolderUrlResult")
        fileManager.stubbedFolderContentResult = [URL(string: "stubbedMocksFolderUrlResult")].compactMap { $0 }
        configs.stubbedConfigs.appFilterConfigs.headerFilterDefaultStyleIgnore = true
        configs.stubbedConfigs.appFilterConfigs.queryFilterDefaultStyleIgnore = true
        configsBuilder.stubbedFindProperHeaderConfigsResult = [.init(key: "platform")]
        configsBuilder.stubbedFindProperPathConfigsResult = [.init(path: "/aboutus", executeAllQueries: true, executeAllHeaders: false)]

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus?id=20&useNewDesign=true&gender=F"))
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
                                "platform": "iPhone",
                                "version": "1.2.3",
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(headers: [
            "platform": "iPhone",
            "version": "1.2.2",
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
                                           shouldNotMock: false,
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
                                           shouldNotMock: false,
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
                                           shouldNotMock: false,
                                           domain: "Dev",
                                           deviceId: "")
        let result = try await decider.decideMock(request: request(),
                                                  flags: flags)

        XCTAssertEqual(result, .useMock(mock: mock))
    }
}
