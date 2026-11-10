//
//  HandleDocsTests.swift
//
//
//  Created for OpenAPI/Swagger documentation feature.
//

import XCTest
import FlyingFox
@testable import Server

final class HandleDocsTests: XCTestCase {
    private var sut: HandleDocs!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = HandleDocs()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        sut = nil
    }

    func test_handleRequest_ReturnsOpenAPISpecWithYamlContentType() async throws {
        // Given
        let request = HTTPRequest.make(method: .GET, path: "/openapi.yaml")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 200)
        XCTAssertEqual(response.headers[HTTPHeader("Content-Type")], "application/yaml")

        let bodyData = try await response.bodyData
        let bodyString = String(data: bodyData, encoding: .utf8)
        XCTAssertTrue(bodyString?.contains("openapi: 3.1.0") ?? false)
        XCTAssertTrue(bodyString?.contains("title: MockingStar Server API") ?? false)
    }
}
