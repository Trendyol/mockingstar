import XCTest
import FlyingSocks
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if os(Linux)
import Glibc
#else
import Darwin
#endif
@testable import Server

final class ServerTests: XCTestCase {
    func testSameServerCanServeMockAfterShutdownAndRestart() async throws {
        let socket = try Socket(domain: AF_INET)
        try socket.bind(to: sockaddr_in.inet(port: 0))
        guard case .ip4(_, let port) = try socket.sockname() else {
            try socket.close()
            return XCTFail("Expected IPv4 listening port")
        }
        try socket.close()
        let server = Server(port: port)
        server.registerMockHandler(RestartMockHandler())
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }

        for _ in 0..<2 {
            let listener = Task { try await server.startServer() }
            do {
                let deadline = Date().addingTimeInterval(5)
                while !(await server.isReady()), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
                let ready = await server.isReady()
                XCTAssertTrue(ready)
                let url = URL(string: "http://127.0.0.1:\(port)/mock?url=https%3A%2F%2Fapi.example.com%2Frestart&method=GET")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 5
                let (body, response) = try await session.data(for: request)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(String(decoding: body, as: UTF8.self), "served")
            } catch {
                await server.shutdown()
                _ = try? await listener.value
                throw error
            }
            await server.shutdown()
            _ = try await listener.value
        }
    }
}

private struct RestartMockHandler: ServerMockHandlerInterface {
    func handle(url: URL, method: String, headers: [String: String], body: Data?, rawFlags: [String: String]) async throws -> (status: Int, body: Data, headers: [String: String]) {
        (200, Data("served".utf8), [:])
    }
}
