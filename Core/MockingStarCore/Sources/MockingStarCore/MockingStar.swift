// The Swift Programming Language
// https://docs.swift.org/swift-book

import AnyCodable
import CommonKit
import Foundation
import PluginCore
import Server

public final class MockingStarCore {
    private let deciderActor = MockDeciderActor()
    private let scenariosActor = ScenarioDecidersActor()
    private let saverActor = FileSaverActor()
    private let jsonEncoder = JSONEncoder.shared
    private let jsonDecoder = JSONDecoder.shared
    private let pluginActor = PluginCoreActor.shared
    private let logger = Logger(category: "MockingStarCore")

    public init() {
        logger.debug("Initialize")
    }

    func handle(request: URLRequest, flags: MockServerFlags) async throws -> (status: Int, body: Data, headers: [String: String]) {
        let decider = try await deciderActor.decider(for: flags.domain)
        let result = try await decider.decideMock(request: request, flags: flags)

        switch result {
        case .useMock(mock: let mock):
            logger.info("Mock found, waiting response time")

            try await Task.sleep(for: .seconds(mock.metaData.responseTime))

            let bodyData = mock.responseBody.data(using: .utf8) ?? .init()
            return (status: mock.metaData.httpStatus,
                    body: bodyData,
                    headers: try mock.responseHeader.asDictionary())
        case .mockNotFound where !flags.disableLiveEnvironment:
            logger.info("Mock not found, trying to request live server: \(request.url?.path() ?? .init())")

            let liveResult = try await proxyRequest(request: request, mockDomain: flags.domain)
            saveFileIfNeeded(request: request,
                             flags: flags,
                             status: liveResult.status,
                             body: liveResult.body,
                             headers: liveResult.headers,
                             decider: decider)
            return liveResult
        case .mockNotFound:
            logger.warning("Mock not found and disable live environment: \(request.url?.path() ?? .init())")
            let pluginMessage = try await pluginActor.pluginCore(for: flags.domain).mockErrorPlugin(message: "Mock not found and disable live environment: \(request.url?.path() ?? .init())")
            return (404, pluginMessage.data(using: .utf8) ?? .init(), [:])
        case .scenarioNotFound where !flags.disableLiveEnvironment:
            logger.info("Scenario not found, trying to request live server")

            let liveResult = try await proxyRequest(request: request, mockDomain: flags.domain)
            saveFileIfNeeded(request: request,
                             flags: flags,
                             status: liveResult.status,
                             body: liveResult.body,
                             headers: liveResult.headers,
                             decider: decider)
            return liveResult
        case .scenarioNotFound:
            logger.warning("Scenario not found and disable live environment")
            let pluginMessage = try await pluginActor.pluginCore(for: flags.domain).mockErrorPlugin(message: "Scenario not found and disable live environment")
            return (404, pluginMessage.data(using: .utf8) ?? .init(), [:])
        }
    }

    /// Send request to real server, it uses two scenario:
    /// First: There is no mock, send real request then mock
    /// Second: Mock Server paused or do not mock this path
    /// - Parameter request: Fully filled URLRequest, it must has all necessary fields for real request
    /// - Returns: HTTP Response: status code, response body, response headers
    private func proxyRequest(request: URLRequest, mockDomain: String) async throws -> (status: Int, body: Data, headers: [String: String]) {
        let updatedRequest = try await pluginActor.pluginCore(for: mockDomain)
            .liveRequestPlugin(request: .init(url: request.url?.absoluteString ?? .init(),
                                              headers: request.allHTTPHeaderFields ?? [:],
                                              body: String(data: request.httpBody ?? .init(), encoding: .utf8) ?? .init(),
                                              method: request.httpMethod ?? .init()))
        var liveRequest = request
        liveRequest.url = URL(string: updatedRequest.url)
        liveRequest.allHTTPHeaderFields = updatedRequest.headers
        liveRequest.httpBody = updatedRequest.body.data(using: .utf8)
        liveRequest.httpMethod = updatedRequest.method

        let (data, response) = try await URLSession.shared.data(for: liveRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Live Request load error")
            return (status: .zero, body: data, headers: [:])
        }

        return (status: httpResponse.statusCode,
                body: data,
                headers: httpResponse.headersDictionary)
    }

    private func saveFileIfNeeded(request: URLRequest, flags: MockServerFlags, status: Int, body: Data, headers: [String: String], decider: MockDeciderInterface) {
        logger.debug("Checking mock should save")

        var shouldSave = decider.mockFilters.contains(where: { filter in
            let filterableItems: [String] = switch filter.selectedLocation {
            case .all: [request.url?.path(percentEncoded: false),
                        request.url?.query(percentEncoded: false),
                        flags.scenario,
                        request.httpMethod,
                        String(status)].compactMap { $0 }
            case .path: [request.url?.path(percentEncoded: false)].compactMap { $0 }
            case .query: [request.url?.query(percentEncoded: false)].compactMap { $0 }
            case .scenario: [flags.scenario].compactMap { $0 }
            case .method: [request.httpMethod].compactMap { $0 }
            case .statusCode: [String(status)]
            }

            return filterableItems.contains(where: {
                let lhs = $0.lowercased()
                let rhs = filter.inputText.lowercased()

                switch filter.selectedFilter {
                case .contains: return lhs.contains(rhs)
                case .notContains: return !lhs.contains(rhs)
                case .startWith:  return lhs.starts(with: rhs)
                case .endWith: return lhs.starts(with: rhs)
                case .equal: return lhs == rhs
                case .notEqual: return lhs != rhs
                }
            })
        })
        
        if decider.mockFilters.isEmpty {
            shouldSave = true
        }

        guard shouldSave else {
            logger.info("Mock won't save due to filters(\(decider.mockFilters.count), path: \(request.url?.path() ?? "-")")
            return
        }

        Task {
            do {
                logger.debug("Saving file")
                try await saveFile(request: request, flags: flags, status: status, body: body, headers: headers)
            } catch {
                logger.critical("File saving failed. Error: \(error)")
            }
        }
    }

    private func saveFile(request: URLRequest, flags: MockServerFlags, status: Int, body: Data, headers: [String: String]) async throws {
        guard let url = request.url else {
            logger.fault("saving File has no url")
            return
        }

        let requestBody: String

        if let requestBodyData = request.httpBody, let requestBodyString = String(data: requestBodyData, encoding: .utf8)  {
            requestBody = requestBodyString
        } else {
            requestBody = .init()
        }

        let responseBody: String

        if let body = String(data: body, encoding: .utf8) {
            responseBody = body
        } else {
            responseBody = .init()
        }

        let metaData = MockModelMetaData(url: url,
                                         method: request.httpMethod.orEmpty,
                                         appendTime: .init(),
                                         updateTime: .init(),
                                         httpStatus: status,
                                         responseTime: 0.15,
                                         scenario: flags.scenario.orEmpty)

        let mock = MockModel(metaData: metaData,
                             requestHeader: .init(request.allHTTPHeaderFields ?? [:]),
                             responseHeader: .init(headers),
                             requestBody: requestBody,
                             responseBody: responseBody)

        try await saverActor.saveFile(mock: mock, mockDomain: flags.domain)
    }
}

// MARK: - ServerMockHandlerInterface
extension MockingStarCore: ServerMockHandlerInterface {
    /// Handles an HTTP request specified by the provided URL, method, headers, body, and raw flags.
    ///
    /// This function performs the following steps:
    /// 1. Constructs a `URLRequest` using the provided URL, method, headers, and body.
    /// 2. Determines the scenario based on the raw flags and the `decider` from the `scenariosActor`.
    /// 3. Creates `MockServerFlags` based on the raw flags and the determined scenario.
    /// 4. Logs the details of the new request and its flags.
    /// 5. Calls the `handle` function with the constructed `URLRequest` and `MockServerFlags`.
    /// 6. Returns the status code, response body, and headers from the `handle` function's result.
    ///
    /// - Parameters:
    ///   - url: The URL of the HTTP request.
    ///   - method: The HTTP method of the request.
    ///   - headers: The headers of the request.
    ///   - body: The body data of the request.
    ///   - rawFlags: Raw flags provided for handling the request.
    /// - Returns: A tuple containing the HTTP status code, response body, and headers.
    /// - Throws: If any error occurs during the handling process, it is thrown.
    public func handle(url: URL, method: String, headers: [String : String], body: Data?, rawFlags: [String: String]) async throws -> (status: Int, body: Data, headers: [String : String]) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.httpBody = body

        let scenario: String
        let mockDomain = rawFlags["mockDomain", default: "Dev"]
        let deviceId = rawFlags["deviceId", default: ""]

        if rawFlags["scenario"].isNilOrEmpty {
            scenario = await scenariosActor.decider(for: mockDomain).decideScenario(request: request, deviceId: deviceId).orEmpty
        } else {
            scenario = rawFlags["scenario", default: ""]
        }

        let flags = MockServerFlags(disableLiveEnvironment: rawFlags["disableLiveEnvironment", default: "false"] == "true",
                                    scenario: scenario,
                                    shouldNotMock: rawFlags["shouldNotMock", default: "false"] == "true",
                                    domain: mockDomain,
                                    deviceId: deviceId)

        logger.debug("Handle new request with \(flags)")

        return try await handle(request: request, flags: flags)
    }
}

// MARK: - ScenarioHandlerInterface
extension MockingStarCore: ScenarioHandlerInterface {
    public func addScenario(scenario: ScenarioModel) async throws {
        await scenariosActor.decider(for: scenario.mockDomain).addNewScenario(scenario)
    }
    
    public func removeScenario(scenario: ScenarioModel) async throws {
        await scenariosActor.decider(for: scenario.mockDomain).removeScenarios(deviceId: scenario.deviceId)
    }
}
