//
//  CORSHandlerTests.swift
//

import XCTest
import FlyingFox
@testable import Server

final class CORSHandlerTests: XCTestCase {
    func test_options_ReturnsNoContentWithCORSHeaders() async throws {
        let sut = CORSHandler(wrapping: ClosureHTTPHandler { _ in
            HTTPResponse(statusCode: .ok)
        })

        let response = try await sut.handleRequest(.make(method: .OPTIONS, path: "/hello"))

        XCTAssertEqual(response.statusCode.code, 204)
        XCTAssertEqual(response.headers[HTTPHeader("Access-Control-Allow-Origin")], "*")
        XCTAssertEqual(response.headers[HTTPHeader("Access-Control-Allow-Methods")], "GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD")
    }

    func test_get_AddsCORSHeadersToWrappedResponse() async throws {
        let sut = CORSHandler(wrapping: ClosureHTTPHandler { _ in
            HTTPResponse(statusCode: .teapot)
        })

        let response = try await sut.handleRequest(.make(method: .GET, path: "/hello"))

        XCTAssertEqual(response.statusCode.code, 418)
        XCTAssertEqual(response.headers[HTTPHeader("Access-Control-Allow-Origin")], "*")
    }
}
