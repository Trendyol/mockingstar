import XCTest
import FlyingFox
@testable import Server

final class PublicEndpointContractTests: XCTestCase {
    func test_hello_ReturnsTeapot() async throws {
        let handler = ClosureHTTPHandler { _ in .init(statusCode: .teapot) }
        let response = try await handler.handleRequest(.make(method: .GET, path: "/hello"))
        XCTAssertEqual(response.statusCode.code, 418)
    }

    func test_openapi_ReturnsYamlContentType() async throws {
        let sut = HandleDocs()
        let response = try await sut.handleRequest(.make(method: .GET, path: "/openapi.yaml"))
        XCTAssertEqual(response.statusCode.code, 200)
        XCTAssertEqual(response.headers[HTTPHeader("Content-Type")], "application/yaml")
        let body = try await response.bodyData
        let text = String(data: body, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("openapi:"))
        XCTAssertTrue(text.contains("/modifiers"))
        XCTAssertTrue(text.contains("ModifierWriteRequest"))
        XCTAssertFalse(text.contains("ModifierBulkUpdate"))
        XCTAssertTrue(text.contains("/modifiers/preview"))
        XCTAssertTrue(text.contains("ModifierPreviewRequest"))
        XCTAssertTrue(text.contains("ModifierPreviewResponse"))
        XCTAssertTrue(text.contains("ModifierAPIErrorResponse"))
        XCTAssertTrue(text.contains("execution_failed"))
    }
}
