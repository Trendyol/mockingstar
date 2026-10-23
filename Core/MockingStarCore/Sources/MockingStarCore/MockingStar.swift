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
    private let deciderActor: MockDeciderActor
    private let scenariosActor: ScenarioDecidersActor
    private let saverActor: FileSaverActor
    private let jsonEncoder = JSONEncoder.shared
    private let jsonDecoder = JSONDecoder.shared
    private let pluginActor: PluginCoreActor
    private let ruleIndex: RuleIndex
    private let journal: RequestJournal?
    private let recordLive: Bool
    private let workspace: MockWorkspace?
    private let logger = Logger(category: "MockingStarCore")

    public init(root: URL? = nil, recordLive: Bool = true) {
        @UserDefaultStorage("workspaces") var workspaces: [Workspace] = []
        let resolvedRoot = root ?? URL(filePath: workspaces.current?.path ?? "/MockServer")
        let builder = FileUrlBuilder(root: root)
        deciderActor = MockDeciderActor(fileStructureHelper: FileStructureHelper(root: root), fileUrlBuilder: builder)
        scenariosActor = ScenarioDecidersActor(fileUrlBuilder: builder, root: root)
        saverActor = FileSaverActor(fileUrlBuilder: builder, workspace: root.map { MockWorkspace(root: $0) })
        pluginActor = root == nil ? PluginCoreActor.shared : PluginCoreActor(fileUrlBuilder: builder, settingsRoot: root)
        ruleIndex = RuleIndex(root: resolvedRoot)
        journal = root.map { RequestJournal(root: $0) }
        self.recordLive = recordLive
        workspace = root.map { MockWorkspace(root: $0) }
        logger.debug("Initialize")
    }

    func handle(request: URLRequest, flags: MockServerFlags, startedAt: ContinuousClock.Instant, requestId: String? = nil) async throws -> (status: Int, body: Data, headers: [String: String]) {
        let (result, decision) = await select(request: request, flags: flags)
        let outcome = decision.mockId != nil ? "mock" : flags.mockSource == .onlyMock ? "blocked" : "live"
        if let requestId {
            do { try await journal?.decision(requestId, decision, outcome: outcome) }
            catch { logJournalFailure(requestId: requestId, stage: "decision", error: error) }
        }
        logger.info("Match decision", metadata: ["requestId": .string(requestId ?? ""), "reason": .string(decision.reason), "mockId": .string(decision.mockId ?? ""), "candidates": .array(decision.candidates.map { .string($0.mockId) }), "traceUrl": .string(request.url?.absoluteString ?? "")])

        switch result {
        case .useMock(mock: let mock):
            logger.info("Mock found, waiting response time", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])

            try await Task.sleep(for: .seconds(mock.metaData.responseTime))
            logMockTrace(request: request, responseType: "mock", startedAt: startedAt, requestId: requestId)

            let bodyData = mock.responseBody.data(using: .utf8) ?? .init()
            return (status: mock.metaData.httpStatus,
                    body: bodyData,
                    headers: try mock.responseHeader.asDictionary())
        case .mockNotFound where flags.mockSource != .onlyMock:
            logger.info("Mock not found, trying to request live server: \(request.url?.path() ?? .init())", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])

            let liveResult = try await proxyRequest(request: request, mockDomain: flags.domain)
            logMockTrace(request: request, responseType: "live request", startedAt: startedAt, requestId: requestId)
            if recordLive, let decider = try? await deciderActor.decider(for: flags.domain) {
                do { try await saveFileIfNeeded(request: request,
                                           flags: flags,
                                           status: liveResult.status,
                                           body: liveResult.body,
                                           headers: liveResult.headers,
                                           decider: decider) } catch { logger.error("Live recording failed: \(error)") }
            }
            return liveResult
        case .mockNotFound:
            logger.warning("Mock not found and disable live environment: \(request.url?.path() ?? .init())", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            let pluginMessage = try await pluginActor.pluginCore(for: flags.domain).mockErrorPlugin(message: "Mock not found and disable live environment: \(request.url?.path() ?? .init())")
            logMockTrace(request: request, responseType: "no mock and disabled live request", startedAt: startedAt, requestId: requestId)
            return (404, pluginMessage.data(using: .utf8) ?? .init(), [:])
        case .scenarioNotFound where flags.mockSource == .default:
            logger.info("Scenario not found, trying to request live server", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])

            let liveResult = try await proxyRequest(request: request, mockDomain: flags.domain)
            logMockTrace(request: request, responseType: "scenario not found and live request", startedAt: startedAt, requestId: requestId)
            if recordLive, let decider = try? await deciderActor.decider(for: flags.domain) {
                do { try await saveFileIfNeeded(request: request,
                                           flags: flags,
                                           status: liveResult.status,
                                           body: liveResult.body,
                                           headers: liveResult.headers,
                                           decider: decider) } catch { logger.error("Live recording failed: \(error)") }
            }
            return liveResult
        case .scenarioNotFound:
            logger.warning("Scenario not found and disable live environment", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            let pluginMessage = try await pluginActor.pluginCore(for: flags.domain).mockErrorPlugin(message: "Scenario not found and disable live environment")
            logMockTrace(request: request, responseType: "scenario not found and disabled live request", startedAt: startedAt, requestId: requestId)
            return (404, pluginMessage.data(using: .utf8) ?? .init(), [:])
        case .ignoreDomain:
            logger.info("Ignoring domain: \(request.url?.host() ?? "_")", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            let liveResult = try await proxyRequest(request: request)
            logMockTrace(request: request, responseType: "ignored domain and live request", startedAt: startedAt, requestId: requestId)
            return liveResult
        }
    }

    private func logMockTrace(request: URLRequest, responseType: String, startedAt: ContinuousClock.Instant, requestId: String? = nil, errorMessage: String? = nil) {
        let duration = String(format: "%.4f", (ContinuousClock().now - startedAt) / .seconds(1))
        if let errorMessage {
            logger.info("Mock Trace", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? ""),
                "responseType": .string(responseType),
                "duration": .string(duration),
                "requestId": .string(requestId ?? ""),
                "method": .string(request.httpMethod ?? ""),
                "errorMessage": .string(errorMessage)
            ])
        } else {
            logger.info("Mock Trace", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? ""),
                "responseType": .string(responseType),
                "duration": .string(duration),
                "requestId": .string(requestId ?? ""),
                "method": .string(request.httpMethod ?? "")
            ])
        }
    }

    private func logJournalFailure(requestId: String, stage: String, error: Error) {
        logger.error("Request journal write failed", metadata: ["requestId": .string(requestId), "stage": .string(stage), "errorCode": .string("journal_write_failed"), "reason": .string(error.localizedDescription)])
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
        let shouldSave = executeMockFilterForShouldSave(for: request, scenario: flags.scenario ?? "", statusCode: status, mockFilters: decider.mockFilters)

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

    /// Evaluates a complete set of mock filters to determine if a request should be saved as a mock.
    ///
    /// This method processes an array of filter configurations and applies them sequentially using logical operations
    /// to determine whether the given request should be automatically saved as a mock file. The evaluation considers
    /// request properties like path, query parameters, HTTP method, status code, and scenario.
    ///
    /// ## Filter Processing Logic
    ///
    /// 1. **Individual Filter Evaluation**: Each filter is evaluated using ``mockFilterResult(_:request:scenario:statusCode:)``
    /// 2. **Logical Combination**: Filter results are combined using AND/OR operators as specified in filter configurations
    /// 3. **Action Determination**: The final action (Mock/Do Not Mock) determines the return value
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    /// let filters = [
    ///     MockFilterConfigModel(selectedLocation: .path, selectedFilter: .contains, inputText: "api", logicType: .mock)
    /// ]
    /// let shouldSave = executeMockFilterForShouldSave(for: request, scenario: "production", statusCode: 200, mockFilters: filters)
    /// ```
    ///
    /// - Parameters:
    ///   - request: The `URLRequest` being evaluated for mock saving
    ///   - scenario: The current mock scenario name (used for scenario-based filtering)
    ///   - statusCode: The HTTP response status code of the request
    ///   - mockFilters: Array of ``MockFilterConfigModel`` configurations to apply
    /// - Returns: `true` if the request should be saved as a mock, `false` otherwise
    ///
    /// - Note: If no filters are provided, the method returns `true` by default (allowing all requests to be saved)
    /// - Warning: Complex filter chains may impact performance. Consider optimizing filter order and specificity.
    ///
    /// ## Filter Logic Flow
    ///
    /// The method follows this logical flow:
    /// 1. Return `true` if no filters are configured (default allow behavior)
    /// 2. Evaluate each filter against the request properties
    /// 3. Combine results using logical operators (AND/OR) in sequence
    /// 4. Apply the final action based on the last action-type filter (Mock/Do Not Mock)
    ///
    /// ## Related Documentation
    ///
    /// - ``mockFilterResult(_:request:scenario:statusCode:)`` - Evaluates individual filters
    /// - ``MockFilterConfigModel`` - Filter configuration structure
    /// - <doc:MockSaveFilters> - Complete guide to mock save filters
    func executeMockFilterForShouldSave(for request: URLRequest, scenario: String, statusCode: Int, mockFilters: [MockFilterConfigModel]) -> Bool {
        guard !mockFilters.isEmpty else { return true }

        var results: [Bool] = []
        var filterLogics: [FilterLogicType] = []

        for filter in mockFilters {
            results.append(mockFilterResult(filter, request: request, scenario: scenario, statusCode: statusCode))

            if filter.logicType.isOperator {
                filterLogics.append(filter.logicType)
            }
        }

        guard !results.isEmpty else { return true }
        var combinedResult: Bool = results[0]

        for filter in zip(results[1...], filterLogics).map({ (result: $0, logic: $1) }) {
            switch filter.logic {
            case .and:
                combinedResult = combinedResult && filter.result
            case .or:
                combinedResult = combinedResult || filter.result
            default:
                break
            }
        }

        return mockFilters.last(where: \.logicType.isAction)?.logicType == .mock ? combinedResult : !combinedResult
    }

    /// Evaluates a single mock filter against request properties to determine if the filter condition is met.
    ///
    /// This method extracts relevant data from the request based on the filter's target location and applies
    /// the specified filter style to determine if the condition matches. All string comparisons are performed
    /// case-insensitively for consistent behavior across different input formats.
    ///
    /// ## Filter Evaluation Process
    ///
    /// 1. **Data Extraction**: Extract relevant strings based on filter location (path, query, method, etc.)
    /// 2. **Case Normalization**: Convert both filter text and request data to lowercase
    /// 3. **Condition Matching**: Apply the filter style (contains, equals, starts with, etc.)
    /// 4. **Result Return**: Return boolean indicating if any extracted data matches the condition
    ///
    /// ## Supported Filter Locations
    ///
    /// - **All**: Combines path, query, scenario, method, and status code
    /// - **Path**: URL path component (e.g., `/api/users/123`)
    /// - **Query**: URL query string (e.g., `page=1&size=10`)
    /// - **Scenario**: Current mock scenario name
    /// - **Method**: HTTP method (GET, POST, PUT, DELETE, etc.)
    /// - **Status Code**: HTTP response status code as string
    ///
    /// ## Filter Styles
    ///
    /// - **Contains**: Check if any data contains the filter text
    /// - **Not Contains**: Check if no data contains the filter text
    /// - **Starts With**: Check if any data starts with the filter text
    /// - **Ends With**: Check if any data ends with the filter text  
    /// - **Equal**: Check if any data exactly equals the filter text
    /// - **Not Equal**: Check if no data exactly equals the filter text
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let filter = MockFilterConfigModel(
    ///     selectedLocation: .path,
    ///     selectedFilter: .contains,
    ///     inputText: "users",
    ///     logicType: .or
    /// )
    /// let request = URLRequest(url: URL(string: "https://api.example.com/api/users/123")!)
    /// let matches = mockFilterResult(filter, request: request, scenario: "production", statusCode: 200)
    /// // Returns: true (path contains "users")
    /// ```
    ///
    /// - Parameters:
    ///   - filter: The ``MockFilterConfigModel`` configuration specifying the filter criteria
    ///   - request: The `URLRequest` being evaluated
    ///   - scenario: The current mock scenario name
    ///   - statusCode: The HTTP response status code
    /// - Returns: `true` if the filter condition is met, `false` otherwise
    ///
    /// - Note: All string comparisons are case-insensitive to ensure consistent matching behavior
    /// - Important: The method returns `true` if ANY of the extracted filterable items match the condition
    ///
    /// ## Implementation Details
    ///
    /// The method uses Swift's pattern matching to extract appropriate data based on the filter location:
    /// - URL components are extracted using `URLRequest.url` properties
    /// - Query parameters are extracted as complete query string
    /// - Status codes are converted to strings for text-based filtering
    /// - All extracted strings are normalized to lowercase before comparison
    ///
    /// ## Related Documentation
    ///
    /// - ``executeMockFilterForShouldSave(for:scenario:statusCode:mockFilters:)`` - Combines multiple filter results
    /// - ``MockFilterConfigModel`` - Filter configuration structure
    /// - <doc:MockSaveFilters> - Complete guide to mock save filters
    func mockFilterResult(_ filter: MockFilterConfigModel, request: URLRequest, scenario: String, statusCode: Int) -> Bool {
        let filterableItems: [String] = switch filter.selectedLocation {
        case .all: [request.url?.path(percentEncoded: false),
                    request.url?.query(percentEncoded: false),
                    scenario,
                    request.httpMethod,
                    String(statusCode)].compactMap { $0 }
        case .path: [request.url?.path(percentEncoded: false)].compactMap { $0 }
        case .query: [request.url?.query(percentEncoded: false)].compactMap { $0 }
        case .scenario: [scenario].compactMap { $0 }
        case .method: [request.httpMethod].compactMap { $0 }
        case .statusCode: [String(statusCode)]
        }

        return filterableItems.contains(where: {
            let lhs = $0.lowercased()
            let rhs = filter.inputText.lowercased()

            switch filter.selectedFilter {
            case .contains: return lhs.contains(rhs)
            case .notContains: return !lhs.contains(rhs)
            case .startWith: return lhs.starts(with: rhs)
            case .endWith: return lhs.hasSuffix(rhs)
            case .equal: return lhs == rhs
            case .notEqual: return lhs != rhs
            }
        })
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
        try workspace?.checkDomain(rawFlags.caseInsensitiveSearch(for: "mockDomain") ?? "Dev")
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw WorkspaceFailure("invalid_url", "Request requires an HTTP(S) URL") }
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

        let startedAt = ContinuousClock().now
        let requestId = journal == nil ? nil : UUID().uuidString
        if let requestId {
            do { _ = try await journal?.begin(domain: mockDomain, request: MatchingRequest(url: url, method: method, headers: headers, body: body, scenario: scenario, deviceId: deviceId), id: requestId) }
            catch { logJournalFailure(requestId: requestId, stage: "begin", error: error) }
        }
        do {
            var result = try await handle(request: request, flags: flags, startedAt: startedAt, requestId: requestId)
            if let requestId {
                do { try await journal?.finish(requestId, status: result.status) }
                catch { logJournalFailure(requestId: requestId, stage: "finish", error: error) }
            }
            if let requestId { result.headers["X-Mockingstar-Request-Id"] = requestId }
            return result
        } catch {
            if let requestId {
                do { try await journal?.finish(requestId, status: nil, error: error.localizedDescription, errorCode: "live_request_failed") }
                catch { logJournalFailure(requestId: requestId, stage: "finish", error: error) }
            }
            logMockTrace(request: request, responseType: "error", startedAt: startedAt, requestId: requestId, errorMessage: error.localizedDescription)
            throw error
        }
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
        try workspace?.checkDomain(mockDomain)
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
        try workspace?.checkDomain(scenario.mockDomain)
        try await scenariosActor.decider(for: scenario.mockDomain).addNewScenario(scenario)
    }
    
    public func removeScenario(scenario: ScenarioModel) async throws {
        try workspace?.checkDomain(scenario.mockDomain)
        try await scenariosActor.decider(for: scenario.mockDomain).removeScenarios(deviceId: scenario.deviceId)
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
        case .mockNotFound, .scenarioNotFound:
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
        }
    }
}

public extension MockingStarCore {
    func listScenarios(domain: String) async throws -> [ScenarioModel] {
        try workspace?.checkDomain(domain)
        return try await scenariosActor.decider(for: domain).listScenarios()
    }
    func explain(request: MatchingRequest, domain: String) async throws -> MatchDecision {
        try workspace?.checkDomain(domain)
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method; urlRequest.allHTTPHeaderFields = request.headers; urlRequest.httpBody = request.body
        return await select(request: urlRequest, flags: .init(mockSource: .default, scenario: request.scenario, domain: domain, deviceId: request.deviceId)).1
    }
}

private extension MockingStarCore {
    func select(request: URLRequest, flags: MockServerFlags) async -> (MockDecision, MatchDecision) {
        let input = MatchingRequest(url: request.url!, method: request.httpMethod ?? "GET", headers: request.allHTTPHeaderFields ?? [:], body: request.httpBody, scenario: flags.scenario ?? "", deviceId: flags.deviceId)
        var decision = MatchDecision()
        if flags.mockSource == .onlyLive { decision.reason = "live_requested"; return (.mockNotFound, decision) }
        do {
            let mocks = try await ruleIndex.mocks(domain: flags.domain)
            decision = RuleMatcher.decide(request: input, mocks: mocks)
            let failures = await ruleIndex.failures(domain: flags.domain)
            decision.candidates += failures
            if decision.mockId == nil && !failures.isEmpty { decision.reason = "mock_load_failed" }
            if let id = decision.mockId, let mock = mocks.first(where: { $0.id == id }) { return (.useMock(mock: mock), decision) }
            let decider = try await deciderActor.decider(for: flags.domain)
            let result = try await decider.decideMock(request: request, flags: flags)
            if case .useMock(let mock) = result {
                decision.mockId = mock.id; decision.reason = "legacy_matched"
                decision.candidates.append(.init(mockId: mock.id, priority: 0, matched: true, failures: []))
            } else if case .ignoreDomain = result { decision.reason = "domain_ignored" }
            else if case .scenarioNotFound = result, decision.candidates.isEmpty { decision.reason = "scenario_not_found" }
            return (result, decision)
        } catch {
            decision.mockId = nil; decision.reason = "mock_load_failed"
            decision.candidates.append(.init(mockId: "", priority: 0, matched: false, failures: [.init(field: "workspace", reason: error.localizedDescription)]))
            logger.error("Mock selection failed; continuing live: \(error)")
            return (.mockNotFound, decision)
        }
    }
}
