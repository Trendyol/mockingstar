//
//  HandleModifier.swift
//
//
//  Created for Partial Mock Modifier feature.
//

import FlyingFox
import Foundation
import CommonKit

public protocol ServerModifierHandlerInterface: AnyObject {
    func listModifiers(domain: String) async throws -> [ModifierModel]
    func getModifier(domain: String, id: String) async throws -> ModifierModel?
    func createModifier(domain: String, model: ModifierModel) async throws
    func updateModifier(domain: String, model: ModifierModel) async throws
    func deleteModifier(domain: String, id: String) async throws
    func bulkUpdate(domain: String?, update: ModifierBulkUpdate) async throws
}

/// Server-facing modifier error, kept independent from `PluginCore` so consumers of `Server`
/// don't need to depend on (or leak) `PluginCore`'s `ModifierStoreError`.
public enum ServerModifierError: LocalizedError {
    case alreadyExists(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyExists(let id): return "Modifier '\(id)' already exists"
        }
    }
}

final class HandleModifier: HTTPHandler {
    static var handler: ServerModifierHandlerInterface?
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let logger = Logger(category: "HandleModifier")

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        logger.debug("New request handled")

        guard let handler = HandleModifier.handler else {
            logger.fault("Handler not registered, you should register handler before handling requests")
            return .init(statusCode: .notImplemented)
        }

        let domainQuery = request.query["domain"]
        let domain = domainQuery ?? "Dev"
        let id = Self.modifierId(fromPath: request.path)

        do {
            switch (request.method, id) {
            case (.GET, .some(let id)):
                return try await handleGet(handler: handler, domain: domain, id: id)
            case (.GET, .none):
                return try await handleList(handler: handler, domain: domain)
            case (.POST, .none):
                return try await handleCreate(handler: handler, domain: domain, request: request)
            case (.PUT, .some(let id)):
                return try await handleUpdate(handler: handler, domain: domain, id: id, request: request)
            case (.PUT, .none):
                return try await handleBulkUpdate(handler: handler, domain: domainQuery, request: request)
            case (.DELETE, .some(let id)):
                logger.info("Deleting modifier, domain \(domain), id \(id)")
                try await handler.deleteModifier(domain: domain, id: id)
                return .init(statusCode: .accepted)
            default:
                return .init(statusCode: .methodNotAllowed)
            }
        } catch ServerModifierError.alreadyExists {
            return .init(statusCode: .conflict)
        } catch {
            logger.error("Handle modifier try error: \(error)")
            throw error
        }
    }

    private func handleList(handler: ServerModifierHandlerInterface, domain: String) async throws -> HTTPResponse {
        let modifiers = try await handler.listModifiers(domain: domain)
        return jsonResponse(statusCode: .ok, body: try jsonEncoder.encode(modifiers))
    }

    private func handleGet(handler: ServerModifierHandlerInterface, domain: String, id: String) async throws -> HTTPResponse {
        guard let modifier = try await handler.getModifier(domain: domain, id: id) else {
            return .init(statusCode: .notFound)
        }
        return jsonResponse(statusCode: .ok, body: try jsonEncoder.encode(modifier))
    }

    private func handleCreate(handler: ServerModifierHandlerInterface, domain: String, request: HTTPRequest) async throws -> HTTPResponse {
        let bodyData = try await request.bodyData
        let model = try jsonDecoder.decode(ModifierModel.self, from: bodyData)
        logger.info("Creating modifier, domain \(domain), id \(model.id)")
        try await handler.createModifier(domain: domain, model: model)
        return .init(statusCode: .created)
    }

    private func handleUpdate(handler: ServerModifierHandlerInterface, domain: String, id: String, request: HTTPRequest) async throws -> HTTPResponse {
        let bodyData = try await request.bodyData
        let model = try jsonDecoder.decode(ModifierModel.self, from: bodyData)
        logger.info("Updating modifier, domain \(domain), id \(id)")
        try await handler.updateModifier(domain: domain, model: model)
        return .init(statusCode: .accepted)
    }

    private func handleBulkUpdate(handler: ServerModifierHandlerInterface, domain: String?, request: HTTPRequest) async throws -> HTTPResponse {
        let bodyData = try await request.bodyData
        let update = try jsonDecoder.decode(ModifierBulkUpdate.self, from: bodyData)
        logger.info("Bulk updating modifiers, domain \(domain ?? "<all>"), enabled \(update.enabled)")
        try await handler.bulkUpdate(domain: domain, update: update)
        return .init(statusCode: .accepted)
    }

    private func jsonResponse(statusCode: HTTPStatusCode, body: Data) -> HTTPResponse {
        .init(statusCode: statusCode, headers: [HTTPHeader("Content-Type"): "application/json"], body: body)
    }

    /// Parses the `{id}` segment from paths like `/modifiers/{id}`.
    /// Returns `nil` for the bare `/modifiers` path (list/create/bulk-update).
    private static func modifierId(fromPath path: String) -> String? {
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard let modifiersIndex = components.firstIndex(of: "modifiers"),
              components.indices.contains(modifiersIndex + 1) else {
            return nil
        }
        return components[modifiersIndex + 1]
    }
}
