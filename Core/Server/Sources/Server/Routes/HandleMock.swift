//
//  HandleMock.swift
//
//
//  Created by Yusuf Özgül on 16.08.2023.
//

import FlyingFox
import Foundation
@preconcurrency import CommonKit

public protocol ServerMockHandlerInterface {
    func handle(url: URL, method: String, headers: [String: String], body: Data?, rawFlags: [String: String]) async throws -> (status: Int, body: Data, headers: [String: String])
}

final class HandleMock: HTTPHandler {
    static var handler: ServerMockHandlerInterface?
    private let jsonDecoder = JSONDecoder()
    private let logger = Logger(category: "HandleMock")

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        logger.debug("New request handled")

        guard let handler = HandleMock.handler else {
            logger.fault("Handler not registered, you should register handler before handling requests")
            return .init(statusCode: .notImplemented)
        }

        do {
            let bodyData = try await request.bodyData
            let mockRequest = try jsonDecoder.decode(MockServerRequestModel.self, from: bodyData)
            let rawFlags: [String: String] = Dictionary(uniqueKeysWithValues: request.headers.map { ($0.key.rawValue, $0.value) })

            let result = try await handler.handle(url: mockRequest.url,
                                                  method: mockRequest.method,
                                                  headers: mockRequest.header ?? [:],
                                                  body: mockRequest.body, 
                                                  rawFlags: rawFlags)

            return .init(statusCode: .init(result.status, phrase: ""),
                         headers: Dictionary(uniqueKeysWithValues: HeaderFilter.filter(result.headers).map { key, value in  (HTTPHeader(key), value.lowercased()) }),
                         body: result.body)
        } catch {
            logger.error("Handle mock try error: \(error)")
            throw error
        }
    }
}

private struct MockServerRequestModel: Codable {
    let method: String
    let url: URL
    let header: [String: String]?
    let body: Data?
    var scenario: String?
    let deviceId: String?
}
