//
//  handler.swift
//
//
//  Created by Yusuf Özgül on 8.11.2023.
//

import FlyingFox
import Foundation
import CommonKit

public protocol ScenarioHandlerInterface {
    func addScenario(scenario: ScenarioModel) async throws
    func removeScenario(scenario: ScenarioModel) async throws
}

final class HandleScenario: HTTPHandler {
    static var handler: ScenarioHandlerInterface?
    private let jsonDecoder = JSONDecoder()
    private let logger = Logger(category: "HandleScenario")

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        logger.debug("New request handled")

        guard let handler = HandleScenario.handler else {
            logger.fault("Handler not registered, you should register handler before handling requests")
            return .init(statusCode: .notImplemented)
        }

        do {
            let bodyData = try await request.bodyData
            let scenario = try jsonDecoder.decode(ScenarioModel.self, from: bodyData)
            let status: HTTPStatusCode

            if request.method == .PUT {
                try await handler.addScenario(scenario: scenario)
                status = .accepted
            } else if request.method == .DELETE {
                try await handler.removeScenario(scenario: scenario)
                status = .accepted
            } else {
                status = .methodNotAllowed
            }

            return .init(statusCode: status)
        } catch {
            logger.error("Handle scenario try error: \(error)")
            throw error
        }
    }
}
