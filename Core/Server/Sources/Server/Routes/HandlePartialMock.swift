//
//  HandlePartialMock.swift
//
//
//  Created for Trendyol Marketing Object Testing
//

import FlyingFox
import Foundation
import CommonKit

public protocol PartialMockHandlerInterface {
    func addPartialMock(partialMock: PartialMockModel) async throws
    func removePartialMock(partialMock: PartialMockModel) async throws
}

final class HandlePartialMock: HTTPHandler {
    static var handler: PartialMockHandlerInterface?
    private let jsonDecoder = JSONDecoder()
    private let logger = Logger(category: "HandlePartialMock")

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        logger.debug("New request handled")

        guard let handler = HandlePartialMock.handler else {
            logger.fault("Handler not registered, you should register handler before handling requests")
            return .init(statusCode: .notImplemented)
        }

        do {
            let bodyData = try await request.bodyData
            let partialMock = try jsonDecoder.decode(PartialMockModel.self, from: bodyData)
            let status: HTTPStatusCode

            if request.method == .PUT {
                logger.info("Adding new partial mock, url: \(partialMock.url)")
                try await handler.addPartialMock(partialMock: partialMock)
                status = .accepted
            } else if request.method == .DELETE {
                logger.info("Removing partial mocks")
                try await handler.removePartialMock(partialMock: partialMock)
                status = .accepted
            } else {
                status = .methodNotAllowed
            }

            return .init(statusCode: status)
        } catch {
            logger.error("Handle partial mock error: \(error)")
            throw error
        }
    }
}
