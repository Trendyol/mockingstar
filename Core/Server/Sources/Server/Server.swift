import FlyingFox
import CommonKit
import Foundation

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
    func registerModifierHandler(_ handler: ServerModifierHandlerInterface)
}

public final class Server: ServerInterface {
    private let logger = Logger(category: "Server")
    private let server: HTTPServer
    private var task: Task<(), Never>? = nil
#if os(macOS)
    private var serverActivity: NSObjectProtocol? = nil
#endif
    private(set) public var id: UUID = .init()
    private(set) public var address: String = ""
    public var serverType: String { "HTTP" }


    public init(port: UInt16 = 8008) {
        server = .init(port: port, logger: Logger(category: "Server"))
        logger.debug("Server initialized on \(port)")
        address = "localhost:\(port)"
    }

    func prepareServer() async {
        // CORS: Swagger "Try it out" often runs cross-origin (localhost vs 127.0.0.1,
        // or IDE embedded browsers). Preflight + response headers keep fetch working.
        await server.appendRoute("OPTIONS *", to: CORSHandler(wrapping: ClosureHTTPHandler { _ in
            CORSHeaders.preflightResponse()
        }))

        await server.appendRoute("POST /mock", to: CORSHandler(wrapping: HandleMock()))
        await server.appendRoute("GET /mock", to: CORSHandler(wrapping: HandleMock()))
        await server.appendRoute("POST /search", to: CORSHandler(wrapping: HandleSearchMock()))
        await server.appendRoute("/scenario", to: CORSHandler(wrapping: HandleScenario()))
        await server.appendRoute("GET /modifiers", to: CORSHandler(wrapping: HandleModifier()))
        await server.appendRoute("POST /modifiers", to: CORSHandler(wrapping: HandleModifier()))
        await server.appendRoute("POST /modifiers/preview", to: CORSHandler(wrapping: HandleModifier()))
        await server.appendRoute("GET /modifiers/*", to: CORSHandler(wrapping: HandleModifier()))
        await server.appendRoute("PUT /modifiers", to: CORSHandler(wrapping: HandleModifier()))
        await server.appendRoute("PUT /modifiers/*", to: CORSHandler(wrapping: HandleModifier()))
        await server.appendRoute("DELETE /modifiers/*", to: CORSHandler(wrapping: HandleModifier()))
        await server.appendRoute("GET /hello", to: CORSHandler(wrapping: ClosureHTTPHandler { _ in
            .init(statusCode: .teapot)
        }))
        await server.appendRoute("GET /openapi.yaml", to: CORSHandler(wrapping: HandleDocs()))
        await server.appendRoute("GET /docs", to: CORSHandler(wrapping: .redirect(to: "/docs/index.html")))
        await server.appendRoute(
            "GET /docs/*",
            to: CORSHandler(wrapping: .directory(for: .module, subPath: "OpenAPI/swagger-ui", serverPath: "docs"))
        )
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
                try await server.start()
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
            try await server.start()
        } catch {
            guard !(error is CancellationError) else { return }
            logger.critical("Server starting error: \(error)")
            throw error
        }
    }

    public func stopServer() {
        logger.debug("Server stopping...")

        guard !(task?.isCancelled ?? true) else {
            logger.notice("Server already stopped")
            return
        }

        task?.cancel()
#if os(macOS)
        if let serverActivity = serverActivity {
            ProcessInfo.processInfo.endActivity(serverActivity)
            self.serverActivity = nil
        }
#endif
    }

    public func registerMockHandler(_ handler: ServerMockHandlerInterface) {
        logger.debug("Server register handler \(String(describing: handler))")
        HandleMock.handler = handler
    }

    public func registerMockSearchHandler(_ handler: ServerMockSearchHandlerInterface) {
        logger.debug("Server register handler \(String(describing: handler))")
        HandleSearchMock.handler = handler
    }

    public func registerScenarioHandler(_ handler: ScenarioHandlerInterface) {
        logger.debug("Server register handler \(String(describing: handler))")
        HandleScenario.handler = handler
    }

    public func registerModifierHandler(_ handler: ServerModifierHandlerInterface) {
        logger.debug("Server register handler \(String(describing: handler))")
        HandleModifier.handler = handler
    }
}
