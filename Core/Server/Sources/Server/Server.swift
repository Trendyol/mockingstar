import FlyingFox
import FlyingSocks
import CommonKit
import Foundation
#if os(Linux)
import Glibc
#endif

public protocol ServerInterface {
    var id: UUID { get }
    var address: String { get }
    var serverType: String { get }

    func startServer(onError: @escaping (Error) -> Void)
    func startServer() async throws
    func stopServer()
    func registerMockHandler(_ handler: ServerMockHandlerInterface)
    func registerMockSearchHandler(_ handler: ServerMockSearchHandlerInterface)
    func registerScenarioHandler(_ handler: ScenarioHandlerInterface)
}

public final class Server: ServerInterface {
    private let logger = Logger(category: "Server")
    private let server: HTTPServer
    private let control: HTTPServer?
    private let token: String?
    private var mockHandler: ServerMockHandlerInterface?
    private var searchHandler: ServerMockSearchHandlerInterface?
    private var scenarioHandler: ScenarioHandlerInterface?
    private var controlHandler: ServerControlHandlerInterface?
    private let requests = RequestDrain()
    private var task: Task<(), Never>? = nil
#if os(macOS)
    private var serverActivity: NSObjectProtocol? = nil
#endif
    private(set) public var id: UUID = .init()
    private(set) public var address: String = ""
    public var serverType: String { "HTTP" }


    public init(port: UInt16 = 8008, controlPort: UInt16? = nil, token: String? = nil) {
        server = .init(port: port, timeout: 120, logger: Logger(category: "Server"))
        self.token = token
        control = controlPort.map {
            var address = sockaddr_in.inet(port: $0)
            address.sin_addr.s_addr = UInt32(0x7f000001).bigEndian
            return HTTPServer(address: address, logger: Logger(category: "Control"))
        }
        logger.debug("Server initialized on \(port)")
        address = "localhost:\(port)"
    }

    func prepareServer() async {
        await requests.openAdmission()
        await server.appendRoute("POST /mock", to: DrainingHandler(next: HandleMock(handler: mockHandler), drain: requests))
        await server.appendRoute("GET /mock", to: DrainingHandler(next: HandleMock(handler: mockHandler), drain: requests))
        await server.appendRoute("POST /search", to: DrainingHandler(next: HandleSearchMock(handler: searchHandler), drain: requests))
        await server.appendRoute("/scenario", to: DrainingHandler(next: HandleScenario(handler: scenarioHandler), drain: requests))
        await server.appendRoute("GET /hello") { _ in return .init(statusCode: .teapot) }
        if let control {
            await control.appendRoute("/*") { [weak self] request in
                guard let self, let token = self.token, request.headers[HTTPHeader("Authorization")] == "Bearer " + token else { return .init(statusCode: .unauthorized) }
                guard let handler = self.controlHandler else { return .init(statusCode: .notImplemented) }
                let result = await handler.control(path: request.path, method: request.method.rawValue, body: (try? await request.bodyData) ?? Data())
                return .init(statusCode: .init(result.status, phrase: ""), headers: [.contentType: "application/json"], body: result.body)
            }
        }
    }

    public func startServer(onError: @escaping (Error) -> Void) {
        logger.debug("Server starting...")

        task?.cancel()
#if os(macOS)
        if let serverActivity = serverActivity {
            ProcessInfo.processInfo.endActivity(serverActivity)
        }
#endif

        task = Task(priority: .high) {
            do {
#if os(macOS)
                serverActivity = ProcessInfo.processInfo.beginActivity(options: ProcessInfo.ActivityOptions.userInitiated,
                                                                       reason: "Mock Server")
#endif
                await prepareServer()
                try await runListeners()
            } catch {
                guard !(error is CancellationError) else { return }
                logger.critical("Server starting error: \(error)")
                onError(error)
            }
        }
    }

    public func startServer() async throws {
        logger.debug("Server starting...")

#if os(macOS)
        if let serverActivity = serverActivity {
            ProcessInfo.processInfo.endActivity(serverActivity)
        }
#endif

        do {
#if os(macOS)
            serverActivity = ProcessInfo.processInfo.beginActivity(options: ProcessInfo.ActivityOptions.userInitiated,
                                                                   reason: "Mock Server")
#endif
            await prepareServer()
            try await runListeners()
        } catch {
            guard !(error is CancellationError) else { return }
            logger.critical("Server starting error: \(error)")
            throw error
        }
    }

    public func stopServer() {
        Task { await shutdown() }
    }

    public func shutdown(timeout: TimeInterval = 120) async {
        await requests.closeAdmission()
        let start = Date()
        while await requests.count > 0, Date().timeIntervalSince(start) < timeout { try? await Task.sleep(for: .milliseconds(25)) }
        await server.stop(timeout: 1)
        await control?.stop(timeout: 1)
        task?.cancel()
#if os(macOS)
        if let serverActivity { ProcessInfo.processInfo.endActivity(serverActivity); self.serverActivity = nil }
#endif
    }

    public func isReady() async -> Bool {
        guard await server.listeningAddress != nil else { return false }
        if let control { return await control.listeningAddress != nil }
        return true
    }

    public func registerControlHandler(_ handler: ServerControlHandlerInterface) { controlHandler = handler }

    private func runListeners() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.server.start() }
            if let control { group.addTask { try await control.start() } }
            defer { group.cancelAll() }
            try await group.next()
        }
    }

    public func registerMockHandler(_ handler: ServerMockHandlerInterface) {
        logger.debug("Server register handler \(String(describing: handler))")
        mockHandler = handler
    }

    public func registerMockSearchHandler(_ handler: ServerMockSearchHandlerInterface) {
        logger.debug("Server register handler \(String(describing: handler))")
        searchHandler = handler
    }

    public func registerScenarioHandler(_ handler: ScenarioHandlerInterface) {
        logger.debug("Server register handler \(String(describing: handler))")
        scenarioHandler = handler
    }
}

public protocol ServerControlHandlerInterface {
    func control(path: String, method: String, body: Data) async -> (status: Int, body: Data)
}

private actor RequestDrain {
    private var accepting = true
    private(set) var count = 0
    func begin() -> Bool { guard accepting else { return false }; count += 1; return true }
    func end() { count -= 1 }
    func closeAdmission() { accepting = false }
    func openAdmission() { accepting = true }
}

private struct DrainingHandler: HTTPHandler {
    let next: HTTPHandler
    let drain: RequestDrain
    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard await drain.begin() else { return .init(statusCode: .serviceUnavailable) }
        do { let response = try await next.handleRequest(request); await drain.end(); return response }
        catch { await drain.end(); throw error }
    }
}
