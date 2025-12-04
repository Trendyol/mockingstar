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
        await server.appendRoute("POST /mock", to: HandleMock())
        await server.appendRoute("GET /mock", to: HandleMock())
        await server.appendRoute("POST /search", to: HandleSearchMock())
        await server.appendRoute("/scenario", to: HandleScenario())
        await server.appendRoute("GET /hello") { _ in return .init(statusCode: .teapot) }
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
}
