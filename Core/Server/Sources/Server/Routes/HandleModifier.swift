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
    func listModifiers(domain: String, deviceId: String) async throws -> [ModifierModel]
    func getModifier(domain: String, id: String, deviceId: String) async throws -> ModifierModel?
    func createModifier(domain: String, model: ModifierModel) async throws
    func updateModifier(domain: String, currentId: String, model: ModifierModel) async throws
    func deleteModifier(domain: String, id: String) async throws
    func setActiveModifiers(domain: String, deviceId: String, ids: [String]) async throws
    func previewModifier(
        domain: String,
        deviceId: String,
        request: ModifierPreviewRequest
    ) async throws -> ModifierPreviewResponse
}

/// Server-facing modifier error, kept independent from `PluginCore` so consumers of `Server`
/// don't need to depend on (or leak) `PluginCore`'s `ModifierStoreError`.
public enum ServerModifierError: LocalizedError {
    case alreadyExists(String)
    case notFound(String)
    case invalidId(String)
    case unknownIds([String])
    case duplicateIds
    case previewInvalidRequest(String)
    case previewNotFound(String)
    case previewConflict(String)
    case previewExecutionFailed(String)
    case previewLiveRequestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyExists(let id): return "modifier '\(id)' already exists"
        case .notFound(let id): return "modifier '\(id)' not found"
        case .invalidId(let id): return "modifier id '\(id)' is invalid"
        case .unknownIds(let ids): return "unknown modifier ids: \(ids.joined(separator: ", "))"
        case .duplicateIds: return "duplicate modifier ids in activation payload"
        case .previewInvalidRequest(let message),
             .previewNotFound(let message),
             .previewConflict(let message),
             .previewExecutionFailed(let message),
             .previewLiveRequestFailed(let message):
            return message
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

        let domain = request.query["domain"] ?? "Dev"
        let deviceId = deviceId(from: request)
        let id = Self.modifierId(fromPath: request.path)

        do {
            switch (request.method, id) {
            case (.GET, .some(let id)):
                return try await handleGet(handler: handler, domain: domain, deviceId: deviceId, id: id)
            case (.GET, .none):
                return try await handleList(handler: handler, domain: domain, deviceId: deviceId)
            case (.POST, .some("preview")):
                return await handlePreview(
                    handler: handler,
                    domain: domain,
                    deviceId: deviceId,
                    request: request
                )
            case (.POST, .none):
                return try await handleCreate(handler: handler, domain: domain, request: request)
            case (.PUT, .some(let id)):
                return try await handleUpdate(handler: handler, domain: domain, id: id, request: request)
            case (.PUT, .none):
                return try await handleSetActive(handler: handler, domain: domain, deviceId: deviceId, request: request)
            case (.DELETE, .some(let id)):
                logger.info("Deleting modifier, domain \(domain), id \(id)")
                try await handler.deleteModifier(domain: domain, id: id)
                return .init(statusCode: .accepted)
            default:
                return .init(statusCode: .methodNotAllowed)
            }
        } catch ServerModifierError.alreadyExists {
            return .init(statusCode: .conflict)
        } catch ServerModifierError.notFound {
            return .init(statusCode: .notFound)
        } catch ServerModifierError.invalidId,
                ServerModifierError.unknownIds,
                ServerModifierError.duplicateIds {
            return .init(statusCode: .badRequest)
        } catch let error as DecodingError {
            logger.error("Handle modifier decode error: \(error)")
            return .init(statusCode: .badRequest)
        } catch {
            logger.error("Handle modifier try error: \(error)")
            throw error
        }
    }

    private func handleList(handler: ServerModifierHandlerInterface, domain: String, deviceId: String) async throws -> HTTPResponse {
        let modifiers = try await handler.listModifiers(domain: domain, deviceId: deviceId)
        return jsonResponse(statusCode: .ok, body: try jsonEncoder.encode(modifiers))
    }

    private func handleGet(handler: ServerModifierHandlerInterface, domain: String, deviceId: String, id: String) async throws -> HTTPResponse {
        guard let modifier = try await handler.getModifier(domain: domain, id: id, deviceId: deviceId) else {
            return .init(statusCode: .notFound)
        }
        return jsonResponse(statusCode: .ok, body: try jsonEncoder.encode(modifier))
    }

    private func handleCreate(handler: ServerModifierHandlerInterface, domain: String, request: HTTPRequest) async throws -> HTTPResponse {
        let bodyData = try await request.bodyData
        let writeRequest = try jsonDecoder.decode(ModifierWriteRequest.self, from: bodyData)
        guard let id = writeRequest.id, !id.isEmpty else {
            throw ServerModifierError.invalidId("")
        }
        let model = writeRequest.asModel(id: id)
        logger.info("Creating modifier, domain \(domain), id \(model.id)")
        try await handler.createModifier(domain: domain, model: model)
        return .init(statusCode: .created)
    }

    private func handleUpdate(handler: ServerModifierHandlerInterface, domain: String, id: String, request: HTTPRequest) async throws -> HTTPResponse {
        let bodyData = try await request.bodyData
        let writeRequest = try jsonDecoder.decode(ModifierWriteRequest.self, from: bodyData)
        let targetId = writeRequest.id ?? id
        let model = writeRequest.asModel(id: targetId)
        logger.info("Updating modifier, domain \(domain), current id \(id), target id \(targetId)")
        try await handler.updateModifier(domain: domain, currentId: id, model: model)
        return .init(statusCode: .accepted)
    }

    private func handleSetActive(handler: ServerModifierHandlerInterface, domain: String, deviceId: String, request: HTTPRequest) async throws -> HTTPResponse {
        let bodyData = try await request.bodyData
        let ids = try jsonDecoder.decode([String].self, from: bodyData)
        logger.info("Setting active modifiers, domain \(domain), deviceId \(deviceId), count \(ids.count)")
        try await handler.setActiveModifiers(domain: domain, deviceId: deviceId, ids: ids)
        return .init(statusCode: .accepted)
    }

    private func handlePreview(
        handler: ServerModifierHandlerInterface,
        domain: String,
        deviceId: String,
        request: HTTPRequest
    ) async -> HTTPResponse {
        do {
            let bodyData = try await request.bodyData
            let preview = try jsonDecoder.decode(ModifierPreviewRequest.self, from: bodyData)
            let result = try await handler.previewModifier(
                domain: domain,
                deviceId: deviceId,
                request: preview
            )
            return jsonResponse(statusCode: .ok, body: try jsonEncoder.encode(result))
        } catch ServerModifierError.previewInvalidRequest(let message) {
            return previewError(status: 400, code: "invalid_request", message: message)
        } catch ServerModifierError.previewNotFound(let message) {
            return previewError(status: 404, code: "not_found", message: message)
        } catch ServerModifierError.previewConflict(let message) {
            return previewError(status: 409, code: "conflict", message: message)
        } catch ServerModifierError.previewExecutionFailed(let message) {
            return previewError(status: 422, code: "execution_failed", message: message)
        } catch ServerModifierError.previewLiveRequestFailed(let message) {
            return previewError(status: 502, code: "live_proxy_failed", message: message)
        } catch let error as DecodingError {
            return previewError(
                status: 400,
                code: "invalid_request",
                message: error.localizedDescription
            )
        } catch {
            logger.error("Modifier preview failed: \(error)")
            return previewError(
                status: 500,
                code: "internal_error",
                message: error.localizedDescription
            )
        }
    }

    private func previewError(
        status: Int,
        code: String,
        message: String
    ) -> HTTPResponse {
        let body = (try? jsonEncoder.encode(
            ModifierAPIErrorResponse(code: code, message: message)
        )) ?? Data()
        return jsonResponse(
            statusCode: .init(status, phrase: ""),
            body: body
        )
    }

    private func deviceId(from request: HTTPRequest) -> String {
        if let header = request.headers[HTTPHeader("deviceId")] {
            return header
        }
        // Match /mock: headers are case-insensitive via FlyingFox, but also accept query for GET-style tools.
        if let query = request.query["deviceId"] {
            return query
        }
        return ""
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
