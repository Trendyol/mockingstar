//
//  CORSHandler.swift
//
//  Enables Swagger UI "Try it out" from browsers / embedded webviews that
//  treat the docs page as a cross-origin client (e.g. localhost vs 127.0.0.1,
//  or Cursor/IDE simple browsers).
//

import FlyingFox
import Foundation

enum CORSHeaders {
    static let allowOrigin = HTTPHeader("Access-Control-Allow-Origin")
    static let allowMethods = HTTPHeader("Access-Control-Allow-Methods")
    static let allowHeaders = HTTPHeader("Access-Control-Allow-Headers")
    static let maxAge = HTTPHeader("Access-Control-Max-Age")

    static let values: [HTTPHeader: String] = [
        allowOrigin: "*",
        allowMethods: "GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD",
        allowHeaders: "*",
        maxAge: "86400",
    ]

    static func preflightResponse() -> HTTPResponse {
        HTTPResponse(statusCode: .noContent, headers: values)
    }

    static func applying(to response: HTTPResponse) -> HTTPResponse {
        var headers = response.headers
        for (key, value) in values {
            headers[key] = value
        }

        switch response.payload {
        case .httpBody(let body):
            return HTTPResponse(
                version: response.version,
                statusCode: response.statusCode,
                headers: headers,
                body: body
            )
        case .webSocket(let handler):
            return HTTPResponse(headers: headers, webSocket: handler)
        }
    }
}

/// Wraps any handler so every response includes CORS headers.
/// OPTIONS requests short-circuit to a 204 preflight response.
struct CORSHandler: HTTPHandler {
    private let next: HTTPHandler

    init(wrapping next: HTTPHandler) {
        self.next = next
    }

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        if request.method == .OPTIONS {
            return CORSHeaders.preflightResponse()
        }

        let response = try await next.handleRequest(request)
        return CORSHeaders.applying(to: response)
    }
}
