//
//  HandleMock.swift
//
//
//  Created by Yusuf Özgül on 16.08.2023.
//

import FlyingFox
import Foundation
import CommonKit

public protocol ServerMockHandlerInterface {
    func handle(url: URL, method: String, headers: [String: String], body: Data?, rawFlags: [String: String]) async throws -> (status: Int, body: Data, headers: [String: String])
}

final class HandleMock: HTTPHandler {
    static var handler: ServerMockHandlerInterface?
    private let jsonDecoder = JSONDecoder()
    private let logger = Logger(category: "HandleMock")

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        logger.debug("New request handled")

        switch request.method {
        case .POST:
            return try await handlePost(request)
        case .GET:
            return try await handleGet(request)
        default:
            logger.fault("Unhandled http method, /mock only allows POST and GET")
            return .init(statusCode: .notImplemented)
        }
    }

    private func handlePost(_ request: HTTPRequest) async throws -> HTTPResponse {
        do {
            let bodyData = try await request.bodyData
            let mockRequest = try jsonDecoder.decode(MockServerRequestModel.self, from: bodyData)
            let rawFlags: [String: String] = Dictionary(uniqueKeysWithValues: request.headers.map { ($0.key.rawValue, $0.value) })

           return try await handleMock(mockRequest: mockRequest, rawFlags: rawFlags)
        } catch {
            logger.error("Handle mock try error: \(error)")
            throw error
        }
    }

    private func handleGet(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let method = request.query[MockServerRequestModel.CodingKeys.method.rawValue],
              let urlString = request.query[MockServerRequestModel.CodingKeys.url.rawValue]?.removingPercentEncoding,
              let url = URL(string: urlString) else {
            return .init(statusCode: .badRequest)
        }

        let headers: [String:String]?
        if let encodedHeaders = request.query[MockServerRequestModel.CodingKeys.header.rawValue] {
            headers = parseHeadersQuery(encodedHeaders)
        } else {
            headers = nil
        }

        let body: Data?
        if let bodyBase64 = request.query[MockServerRequestModel.CodingKeys.body.rawValue] {
            body = Data(base64Encoded: bodyBase64)
        } else {
            body = nil
        }

        do {
            let mockRequest = MockServerRequestModel(method: method,
                                                     url: url,
                                                     header: headers,
                                                     body: body)
            let rawFlags: [String: String] = Dictionary(uniqueKeysWithValues: request.headers.map { ($0.key.rawValue, $0.value) })

           return try await handleMock(mockRequest: mockRequest, rawFlags: rawFlags)
        } catch {
            logger.error("Handle mock try error: \(error)")
            throw error
        }
    }

    private func handleMock(mockRequest: MockServerRequestModel, rawFlags: [String: String]) async throws -> HTTPResponse {
        guard let handler = HandleMock.handler else {
            logger.fault("Handler not registered, you should register handler before handling requests")
            return .init(statusCode: .notImplemented)
        }

        let result = try await handler.handle(url: mockRequest.url,
                                              method: mockRequest.method,
                                              headers: mockRequest.header ?? [:],
                                              body: mockRequest.body,
                                              rawFlags: rawFlags)

        return .init(statusCode: .init(result.status, phrase: ""),
                     headers: Dictionary(uniqueKeysWithValues: HeaderFilter.filter(result.headers).map { key, value in  (HTTPHeader(key), value) }),
                     body: result.body)
    }

    private func parseHeadersQuery(_ encodedString: String) -> [String: String] {
        guard let decoded = encodedString.removingPercentEncoding else { return [:] }

        return Dictionary(uniqueKeysWithValues:
            decoded.components(separatedBy: ",")
                .compactMap { pair -> (String, String)? in
                    let parts = pair.components(separatedBy: "=")
                    guard parts.count == 2 else { return nil }
                    return (parts[0].trimmingCharacters(in: .whitespaces),
                            parts[1].trimmingCharacters(in: .whitespaces))
                }
        )
    }
}

private struct MockServerRequestModel: Codable {
    let method: String
    let url: URL
    let header: [String: String]?
    let body: Data?

    enum CodingKeys: String, CodingKey {
        case method
        case url
        case header
        case body
    }
}
