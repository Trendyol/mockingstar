// The Swift Programming Language
// https://docs.swift.org/swift-book

import AnyCodable
import CommonKit
import Foundation
#if os(macOS)
import PluginCore
#elseif os(Linux)
import PluginCoreLinux
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Server

public protocol MockingStarCoreInterface {
    func importMock(url: URL, method: String, headers: [String: String], body: Data?, flags: MockServerFlags) async throws -> MockImportResult
}

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
            logger.info("Mock found, waiting response time", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])

            try await Task.sleep(for: .seconds(mock.metaData.responseTime))

            let bodyData = mock.responseBody.data(using: .utf8) ?? .init()
            return (status: mock.metaData.httpStatus,
                    body: bodyData,
                    headers: try mock.responseHeader.asDictionary())
        case .mockNotFound where flags.mockSource == .default:
            logger.info("Mock not found, trying to request live server: \(request.url?.path() ?? .init())", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])

            let liveResult = try await proxyRequest(request: request, mockDomain: flags.domain)
            Task {
                try await saveFileIfNeeded(request: request,
                                           flags: flags,
                                           status: liveResult.status,
                                           body: liveResult.body,
                                           headers: liveResult.headers,
                                           decider: decider)
            }
            return liveResult
        case .mockNotFound:
            logger.warning("Mock not found and disable live environment: \(request.url?.path() ?? .init())", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            let pluginMessage = try await pluginActor.pluginCore(for: flags.domain).mockErrorPlugin(message: "Mock not found and disable live environment: \(request.url?.path() ?? .init())")
            return (404, pluginMessage.data(using: .utf8) ?? .init(), [:])
        case .scenarioNotFound where flags.mockSource == .default:
            logger.info("Scenario not found, trying to request live server", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])

            let liveResult = try await proxyRequest(request: request, mockDomain: flags.domain)
            Task {
                try await saveFileIfNeeded(request: request,
                                           flags: flags,
                                           status: liveResult.status,
                                           body: liveResult.body,
                                           headers: liveResult.headers,
                                           decider: decider)
            }
            return liveResult
        case .scenarioNotFound:
            logger.warning("Scenario not found and disable live environment", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            let pluginMessage = try await pluginActor.pluginCore(for: flags.domain).mockErrorPlugin(message: "Scenario not found and disable live environment")
            return (404, pluginMessage.data(using: .utf8) ?? .init(), [:])
        case .ignoreDomain:
            logger.info("Ignoring domain: \(request.url?.host() ?? "_")", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            return try await proxyRequest(request: request)
        }
    }

    /// Send request to real server, it uses multiple scenarios:
    ///   - There is no mock, send real request then mock.
    ///   - Mock Server paused or do not mock this path.
    ///   - Domain should not mock and ignore.
    ///   - Request live response based on mocked request.
    /// - Parameter request: Fully filled URLRequest, it must has all necessary fields for real request
    /// - Returns: HTTP Response: status code, response body, response headers
    private func proxyRequest(request: URLRequest, mockDomain: String? = nil) async throws -> (status: Int, body: Data, headers: [String: String]) {
        let liveRequest: URLRequest

        if let mockDomain {
            liveRequest = try await updateProxyRequestWithPlugin(request: request, mockDomain: mockDomain).recalculateContentLength()
        } else {
            liveRequest = request.recalculateContentLength()
        }

        let (data, response) = try await URLSession.shared.data(for: liveRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Live Request load error", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            return (status: .zero, body: data, headers: [:])
        }

        return (status: httpResponse.statusCode,
                body: data,
                headers: httpResponse.headersDictionary)
    }
    
    /// Update request before sending real server with plugin.
    /// - Parameters:
    ///   - request: mocked or original request from client.
    ///   - mockDomain: Currently working mock domain.
    /// - Returns: Updated `URLRequest` by `liveRequestPlugin`.
    private func updateProxyRequestWithPlugin(request: URLRequest, mockDomain: String) async throws -> URLRequest {
        var liveRequest = request

        let updatedRequest = try await pluginActor.pluginCore(for: mockDomain)
            .liveRequestPlugin(request: .init(url: request.url?.absoluteString ?? .init(),
                                              headers: request.allHTTPHeaderFields ?? [:],
                                              body: String(data: request.httpBody ?? .init(), encoding: .utf8) ?? .init(),
                                              method: request.httpMethod ?? .init()))

        liveRequest.url = URL(string: updatedRequest.url)
        liveRequest.allHTTPHeaderFields = updatedRequest.headers
        liveRequest.httpBody = updatedRequest.body.data(using: .utf8)
        liveRequest.httpMethod = updatedRequest.method

        return liveRequest
    }

    private func saveFileIfNeeded(request: URLRequest, flags: MockServerFlags, status: Int, body: Data, headers: [String: String], decider: MockDeciderInterface) async throws {
        logger.debug("Checking mock should save", metadata: [
            "traceUrl": .string(request.url?.absoluteString ?? "")
        ])
        var request = request

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

        if let pathComponents = request.url?.pathComponents, pathComponents.count >= 10 {
            logger.error("Request path components count more than limit.", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            throw MockSaveResult.pathComponentLimitExceeded
        }

        guard shouldSave else {
            logger.info("Mock won't save due to filters (\(decider.mockFilters.count)), path: \(request.url?.path() ?? "-")", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            throw MockSaveResult.preventedByFilters
        }

        guard body == "".data(using: .utf8) || (try? JSONSerialization.jsonObject(with: body)) != nil else {
            logger.warning("Mock won't save due to response body is not json, path: \(request.url?.path() ?? "-")", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            throw MockSaveResult.responseBodyFormatError
        }

        if let requestBody = request.httpBody {
            if requestBody == "".data(using: .utf8) {
                request.httpBody = nil
            } else if (try? JSONSerialization.jsonObject(with: requestBody)) == nil {
                logger.warning("Mock won't save due to request body is not json, path: \(request.url?.path() ?? "-")", metadata: [
                    "traceUrl": .string(request.url?.absoluteString ?? "")
                ])
                throw MockSaveResult.requestBodyFormatError
            }
        }

        do {
            logger.debug("Saving file", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            try await saveFile(request: request, flags: flags, status: status, body: body, headers: headers)
        } catch {
            logger.critical("File saving failed. Error: \(error)", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            throw error
        }
    }

    private func saveFile(request: URLRequest, flags: MockServerFlags, status: Int, body: Data, headers: [String: String]) async throws {
        guard let url = request.url else {
            logger.fault("saving File has no url", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            throw MockSaveResult.noUrlFound
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
        let mockDomain = rawFlags.caseInsensitiveSearch(for: "mockDomain") ?? "Dev"
        let deviceId = rawFlags.caseInsensitiveSearch(for: "deviceId").orEmpty

        if rawFlags.caseInsensitiveSearch(for: "scenario").isNilOrEmpty {
            scenario = await scenariosActor.decider(for: mockDomain).decideScenario(request: request, deviceId: deviceId).orEmpty
        } else {
            scenario = rawFlags.caseInsensitiveSearch(for: "scenario").orEmpty
        }

        let flags = MockServerFlags(mockSource: .init(from: rawFlags),
                                    scenario: scenario,
                                    domain: mockDomain,
                                    deviceId: deviceId)

        logger.debug("Handle new request with \(flags)", metadata: [
            "traceUrl": .string(url.absoluteString)
        ])

        return try await handle(request: request, flags: flags)
    }
}

// MARK: - ServerMockSearchHandlerInterface
extension MockingStarCore: ServerMockSearchHandlerInterface {
    /// The `search` function makes an HTTP request with the specified parameters, using mock data or fetching data from a real server.
    /// - Parameters:
    ///   - path: The path of the HTTP request.
    ///   - method: The method of the HTTP request (GET, POST, etc.).
    ///   - scenario: Optional. The name of the scenario.
    ///   - rawFlags: A dictionary containing key-value pairs for custom flags.
    /// - Returns: The function returns a tuple:
    ///   - `status`: The HTTP response status code.
    ///   - `body`: The response body as `Data`.
    ///   - `headers`: The response headers as `[String : String]`.
    public func search(path: String, method: String, scenario: String?, rawFlags: [String : String]) async throws -> (status: Int, body: Data, headers: [String : String]) {
        let mockDomain = rawFlags.caseInsensitiveSearch(for: "mockDomain") ?? "Dev"
        let deviceId = rawFlags.caseInsensitiveSearch(for: "deviceId").orEmpty

        let flags = MockServerFlags(mockSource: .init(from: rawFlags),
                                    scenario: scenario,
                                    domain: mockDomain,
                                    deviceId: deviceId)

        let decider = try await deciderActor.decider(for: flags.domain)
        let result = try await decider.searchMock(path: path, method: method, flags: flags)

        switch result {
        case .useMock(let mock) where flags.mockSource == .onlyLive:
            logger.info("Mock found, loading live response")
            return try await proxyRequest(request: mock.asURLRequest, mockDomain: mockDomain)
        case .useMock(let mock):
            logger.info("Mock found, waiting response time")

            try await Task.sleep(for: .seconds(mock.metaData.responseTime))

            let bodyData = mock.responseBody.data(using: .utf8) ?? .init()
            return (status: mock.metaData.httpStatus,
                    body: bodyData,
                    headers: try mock.responseHeader.asDictionary())
        default:
            logger.warning("Mock searched and not found: \(path)")
            let pluginMessage = try await pluginActor.pluginCore(for: flags.domain).mockErrorPlugin(message: "Mock not found and disable live environment: \(path)")
            return (404, pluginMessage.data(using: .utf8) ?? .init(), [:])
        }
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

// MARK: - Import
extension MockingStarCore: MockingStarCoreInterface {
    public func importMock(url: URL, method: String, headers: [String: String], body: Data?, flags: MockServerFlags) async throws -> MockImportResult {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.httpBody = body
        let decider = try await deciderActor.decider(for: flags.domain)
        let result = try await decider.decideMock(request: request, flags: flags)

        switch result {
        case .useMock:
            return .alreadyMocked
        case .mockNotFound:
            logger.info("Mock not found, trying to request live server: \(request.url?.path() ?? .init())")

            let liveResult = try await proxyRequest(request: request, mockDomain: flags.domain)
            try await saveFileIfNeeded(request: request,
                                       flags: flags,
                                       status: liveResult.status,
                                       body: liveResult.body,
                                       headers: liveResult.headers,
                                       decider: decider)
            return .mocked
        case .ignoreDomain:
            return .domainIgnoredByConfigs
        default:
            return .unhandled
        }
    }
}
