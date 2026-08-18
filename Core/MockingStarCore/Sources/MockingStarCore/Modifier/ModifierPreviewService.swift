import CommonKit
import Foundation
#if os(macOS)
import PluginCore
#elseif os(Linux)
import PluginCoreLinux
#endif

private final class FirstResultCapture {
    private let lock = NSLock()
    private var stored: HTTPResult?

    func captureIfNeeded(_ result: HTTPResult) {
        lock.lock()
        defer { lock.unlock() }
        if stored == nil { stored = result }
    }

    var value: HTTPResult? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

enum ModifierPreviewError: Error, Equatable {
    case invalidRequest(String)
    case currentModifierNotFound(String)
    case mockNotFound(String)
    case conflict(String)
    case executionFailed(String)
    case liveRequestFailed(String)
}

struct ModifierPreviewService {
    let activationStore: ModifierActivationStore
    let storedMockLoader: StoredMockLoader

    func execute(
        domain: String,
        deviceId: String,
        preview: ModifierPreviewRequest,
        liveTerminal: @escaping (URLRequest) async throws -> HTTPResult
    ) async throws -> ModifierPreviewResponse {
        guard let desiredId = preview.modifier.id, !desiredId.isEmpty else {
            throw ModifierPreviewError.invalidRequest("modifier id is required")
        }
        guard preview.modifier.order >= 1 else {
            throw ModifierPreviewError.invalidRequest("Order must be at least 1")
        }
        guard !preview.request.method.isEmpty else {
            throw ModifierPreviewError.invalidRequest("HTTP method is required")
        }

        let store = await ModifierStoreActor.shared.store(for: domain)
        do {
            guard try store.get(id: preview.currentModifierId) != nil else {
                throw ModifierPreviewError.currentModifierNotFound(
                    preview.currentModifierId
                )
            }
            if desiredId != preview.currentModifierId,
               try store.get(id: desiredId) != nil {
                throw ModifierPreviewError.conflict(desiredId)
            }
        } catch let error as ModifierPreviewError {
            throw error
        } catch ModifierStoreError.invalidId(let id) {
            throw ModifierPreviewError.invalidRequest("Invalid modifier id: \(id)")
        }

        var request = URLRequest(url: preview.request.url)
        request.httpMethod = preview.request.method.uppercased()
        request.allHTTPHeaderFields = preview.request.headers
        guard let body = Data(base64Encoded: preview.request.bodyBase64) else {
            throw ModifierPreviewError.invalidRequest("Body is not valid Base64")
        }
        request.httpBody = body.isEmpty ? nil : body

        let activeIds = await activationStore.activeModifierIds(domain: domain, deviceId: deviceId)
        var candidates = try store.get(ids: Array(activeIds))
        candidates.removeAll {
            $0.id == preview.currentModifierId || $0.id == desiredId
        }
        let draft = preview.modifier.asModel(id: desiredId)
        candidates.append(draft)

        let matched = ModifierMatcher().match(
            modifiers: candidates,
            path: preview.request.url.path(),
            method: preview.request.method,
            scenario: preview.request.scenario
        )
        guard matched.contains(where: { $0.id == desiredId }) else {
            throw ModifierPreviewError.invalidRequest(
                "Preview request does not match the draft modifier"
            )
        }

        let originalCapture = FirstResultCapture()

        let chain = ModifierChain(modifiers: matched, executionMode: .preview) { chainRequest in
            let result: HTTPResult
            switch preview.source {
            case .mock:
                guard let mockId = preview.modifier.sampleMockRequestId, !mockId.isEmpty else {
                    throw ModifierPreviewError.invalidRequest(
                        "Sample mock id is required for Mock source"
                    )
                }
                let mock = try storedMockLoader.load(
                    domain: domain,
                    requestURL: preview.request.url,
                    method: preview.request.method,
                    scenario: preview.request.scenario ?? "",
                    id: mockId
                )
                result = HTTPResult(
                    status: mock.metaData.httpStatus,
                    body: Data(mock.responseBody.utf8),
                    headers: try mock.responseHeader.asDictionary()
                )
            case .live:
                do {
                    result = try await liveTerminal(chainRequest)
                } catch {
                    throw ModifierPreviewError.liveRequestFailed(error.localizedDescription)
                }
            }
            originalCapture.captureIfNeeded(result)
            return result
        }

        do {
            let result = try await chain.proceed(request)
            let original = originalCapture.value
            return ModifierPreviewResponse(
                status: result.status,
                headers: result.headers,
                bodyBase64: result.body.base64EncodedString(),
                originalStatus: original?.status,
                originalHeaders: original?.headers,
                originalBodyBase64: original?.body.base64EncodedString()
            )
        } catch let error as ModifierPreviewError {
            throw error
        } catch {
            throw ModifierPreviewError.executionFailed(String(describing: error))
        }
    }
}
