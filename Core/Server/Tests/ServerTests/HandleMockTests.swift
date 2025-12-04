//
//  HandleMockTests.swift
//
//
//  Created by Yusuf Özgül on 4.12.2024.
//

import XCTest
import FlyingFox
@testable import Server

final class HandleMockTests: XCTestCase {
    private var sut: HandleMock!
    private var mockHandler: MockServerHandler!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = HandleMock()
        mockHandler = MockServerHandler()
        HandleMock.handler = mockHandler
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        sut = nil
        HandleMock.handler = nil
    }

    // MARK: - POST Request Tests

    func test_handleRequest_POST_Success() async throws {
        // Given
        let url = URL(string: "https://api.example.com/users")!
        let requestBody = MockServerRequest(method: "GET", url: url, header: ["Content-Type": "application/json"], body: nil)
        let bodyData = try JSONEncoder().encode(requestBody)

        mockHandler.stubbedResult = (status: 200, body: Data("{\"success\": true}".utf8), headers: ["Content-Type": "application/json"])

        let request = HTTPRequest.make(method: .POST, path: "/mock", body: bodyData)

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 200)
        XCTAssertTrue(mockHandler.invokedHandle)
        XCTAssertEqual(mockHandler.invokedHandleParameters?.url, url)
        XCTAssertEqual(mockHandler.invokedHandleParameters?.method, "GET")
    }

    func test_handleRequest_POST_WithBody() async throws {
        // Given
        let url = URL(string: "https://api.example.com/users")!
        let bodyContent = Data("{\"name\": \"test\"}".utf8)
        let requestBody = MockServerRequest(method: "POST", url: url, header: nil, body: bodyContent)
        let bodyData = try JSONEncoder().encode(requestBody)

        mockHandler.stubbedResult = (status: 201, body: Data(), headers: [:])

        let request = HTTPRequest.make(method: .POST, path: "/mock", body: bodyData)

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 201)
        XCTAssertEqual(mockHandler.invokedHandleParameters?.body, bodyContent)
    }

    func test_handleRequest_POST_HandlerNotRegistered() async throws {
        // Given
        HandleMock.handler = nil
        let url = URL(string: "https://api.example.com/users")!
        let requestBody = MockServerRequest(method: "GET", url: url, header: nil, body: nil)
        let bodyData = try JSONEncoder().encode(requestBody)

        let request = HTTPRequest.make(method: .POST, path: "/mock", body: bodyData)

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 501)
    }

    // MARK: - GET Request Tests

    func test_handleRequest_GET_Success() async throws {
        // Given
        let url = URL(string: "https://api.example.com/users")!
        let encodedUrl = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        mockHandler.stubbedResult = (status: 200, body: Data("{\"data\": []}".utf8), headers: ["Content-Type": "application/json"])

        let request = HTTPRequest.make(method: .GET, path: "/mock?method=GET&url=\(encodedUrl)")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 200)
        XCTAssertTrue(mockHandler.invokedHandle)
        XCTAssertEqual(mockHandler.invokedHandleParameters?.url, url)
        XCTAssertEqual(mockHandler.invokedHandleParameters?.method, "GET")
    }

    func test_handleRequest_GET_WithHeaders() async throws {
        // Given
        let url = URL(string: "https://api.example.com/users")!
        let encodedUrl = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let headers = "Authorization=Bearer%20token,Content-Type=application/json"
        mockHandler.stubbedResult = (status: 200, body: Data(), headers: [:])

        let request = HTTPRequest.make(method: .GET, path: "/mock?method=GET&url=\(encodedUrl)&header=\(headers)")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 200)
        XCTAssertEqual(mockHandler.invokedHandleParameters?.headers["Authorization"], "Bearer token")
        XCTAssertEqual(mockHandler.invokedHandleParameters?.headers["Content-Type"], "application/json")
    }

    func test_handleRequest_GET_WithBody() async throws {
        // Given
        let url = URL(string: "https://api.example.com/users")!
        let encodedUrl = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let bodyData = Data("{\"test\": true}".utf8)
        let bodyBase64 = bodyData.base64EncodedString()
        mockHandler.stubbedResult = (status: 200, body: Data(), headers: [:])

        let request = HTTPRequest.make(method: .GET, path: "/mock?method=POST&url=\(encodedUrl)&body=\(bodyBase64)")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 200)
        XCTAssertEqual(mockHandler.invokedHandleParameters?.body, bodyData)
    }

    func test_handleRequest_GET_MissingMethod_ReturnsBadRequest() async throws {
        // Given
        let url = URL(string: "https://api.example.com/users")!
        let encodedUrl = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

        let request = HTTPRequest.make(method: .GET, path: "/mock?url=\(encodedUrl)")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 400)
        XCTAssertFalse(mockHandler.invokedHandle)
    }

    func test_handleRequest_GET_MissingUrl_ReturnsBadRequest() async throws {
        // Given
        let request = HTTPRequest.make(method: .GET, path: "/mock?method=GET")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 400)
        XCTAssertFalse(mockHandler.invokedHandle)
    }

    func test_handleRequest_GET_InvalidUrl_ReturnsBadRequest() async throws {
        // Given
        let request = HTTPRequest.make(method: .GET, path: "/mock?method=GET&url=")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 400)
        XCTAssertFalse(mockHandler.invokedHandle)
    }

    func test_handleRequest_GET_HandlerNotRegistered() async throws {
        // Given
        HandleMock.handler = nil
        let url = URL(string: "https://api.example.com/users")!
        let encodedUrl = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

        let request = HTTPRequest.make(method: .GET, path: "/mock?method=GET&url=\(encodedUrl)")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 501)
    }

    // MARK: - Unsupported HTTP Method Tests

    func test_handleRequest_PUT_ReturnsNotImplemented() async throws {
        // Given
        let request = HTTPRequest.make(method: .PUT, path: "/mock")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 501)
    }

    func test_handleRequest_DELETE_ReturnsNotImplemented() async throws {
        // Given
        let request = HTTPRequest.make(method: .DELETE, path: "/mock")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 501)
    }

    func test_handleRequest_PATCH_ReturnsNotImplemented() async throws {
        // Given
        let request = HTTPRequest.make(method: .PATCH, path: "/mock")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 501)
    }

    // MARK: - Response Header Tests

    func test_handleRequest_ReturnsFilteredHeaders() async throws {
        // Given
        let url = URL(string: "https://api.example.com/users")!
        let requestBody = MockServerRequest(method: "GET", url: url, header: nil, body: nil)
        let bodyData = try JSONEncoder().encode(requestBody)

        mockHandler.stubbedResult = (
            status: 200,
            body: Data(),
            headers: ["Content-Type": "application/json", "X-Custom-Header": "custom-value"]
        )

        let request = HTTPRequest.make(method: .POST, path: "/mock", body: bodyData)

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 200)
    }
}

// MARK: - Mock Handler

private final class MockServerHandler: ServerMockHandlerInterface {
    var invokedHandle = false
    var invokedHandleParameters: (url: URL, method: String, headers: [String: String], body: Data?, rawFlags: [String: String])?
    var stubbedResult: (status: Int, body: Data, headers: [String: String]) = (200, Data(), [:])

    func handle(url: URL, method: String, headers: [String: String], body: Data?, rawFlags: [String: String]) async throws -> (status: Int, body: Data, headers: [String: String]) {
        invokedHandle = true
        invokedHandleParameters = (url, method, headers, body, rawFlags)
        return stubbedResult
    }
}

// MARK: - Mock Request Model

private struct MockServerRequest: Codable {
    let method: String
    let url: URL
    let header: [String: String]?
    let body: Data?
}

// MARK: - HTTPRequest Helper

extension HTTPRequest {
    static func make(method: HTTPMethod, path: String, body: Data = Data(), headers: [HTTPHeader: String] = [:]) -> HTTPRequest {
        var components = URLComponents(string: "http://localhost:8080\(path)")!
        let query = components.queryItems ?? []

        var allHeaders = headers
        allHeaders[HTTPHeader("Host")] = "localhost:8080"

        return HTTPRequest(
            method: method,
            version: .http11,
            path: components.path,
            query: query.map({ .init(name: $0.name, value: $0.value ?? "") }),
            headers: allHeaders,
            body: body
        )
    }
}

