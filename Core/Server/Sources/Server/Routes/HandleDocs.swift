//
//  HandleDocs.swift
//
//
//  Created for OpenAPI/Swagger documentation feature.
//

import FlyingFox
import Foundation
import CommonKit

/// Serves the hand-written OpenAPI spec at `GET /openapi.yaml`.
/// The Swagger UI static assets themselves are served separately via
/// FlyingFox's built-in `DirectoryHTTPHandler`, registered in `Server.swift`.
final class HandleDocs: HTTPHandler {
    private let logger = Logger(category: "HandleDocs")

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        logger.debug("New request handled")

        guard let specURL = Bundle.module.url(forResource: "openapi", withExtension: "yaml", subdirectory: "OpenAPI") else {
            logger.fault("openapi.yaml resource not found in bundle")
            return .init(statusCode: .notFound)
        }

        return try await FileHTTPHandler(path: specURL, contentType: "application/yaml").handleRequest(request)
    }
}
