import CommonKit
import Foundation
#if os(macOS)
import PluginCore
#elseif os(Linux)
import PluginCoreLinux
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Server

/// Owns modifier matching, the JS chain, disk CRUD, device activation, and preview.
/// `MockingStarCore` only supplies the mock/live terminal.
final class MockModifierGateway {
    private let activationStore: MockModifierActivationStore
    private let previewService: MockModifierPreviewService
    private let storeActor: MockModifierStoreActor
    private let logger = Logger(category: "MockModifierGateway")

    init(activationStore: MockModifierActivationStore,
         previewService: MockModifierPreviewService,
         storeActor: MockModifierStoreActor) {
        self.activationStore = activationStore
        self.previewService = previewService
        self.storeActor = storeActor
    }

    func handle(
        request: URLRequest,
        flags: MockServerFlags,
        terminal: @escaping (URLRequest, MockServerFlags) async throws -> (status: Int, body: Data, headers: [String: String])
    ) async throws -> (status: Int, body: Data, headers: [String: String]) {
        let requestPath = request.url?.path() ?? ""
        let requestMethod = request.httpMethod ?? ""
        let activeSources = await activationStore.activeModifierSources(domain: flags.domain, deviceId: flags.deviceId)
        let activeIds = Set(activeSources.keys)
        guard !activeIds.isEmpty else {
            logger.info("modifier skip: no active ids", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? ""),
                "domain": .string(flags.domain),
                "deviceId": .string(flags.deviceId),
                "path": .string(requestPath),
                "method": .string(requestMethod),
                "scenario": .string(flags.scenario ?? "")
            ])
            return try await terminal(request, flags)
        }

        let store = await storeActor.store(for: flags.domain)
        let activeModifiers = (try? store.get(ids: Array(activeIds))) ?? []
        let matchedModifiers = MockModifierMatcher().match(modifiers: activeModifiers,
                                                       path: requestPath,
                                                       method: requestMethod,
                                                       scenario: flags.scenario)

        guard !matchedModifiers.isEmpty else {
            logger.info("modifier skip: no path/method/scenario match", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? ""),
                "domain": .string(flags.domain),
                "deviceId": .string(flags.deviceId),
                "path": .string(requestPath),
                "method": .string(requestMethod),
                "scenario": .string(flags.scenario ?? ""),
                "activeIds": .string(activeIds.sorted().joined(separator: ","))
            ])
            return try await terminal(request, flags)
        }

        let matchedSources = matchedModifiers.compactMap { activeSources[$0.id] }
        let terminalIsMock = flags.mockSource == .onlyMock || !matchedSources.contains(.live)

        let terminalFlags: MockServerFlags
        if terminalIsMock {
            terminalFlags = MockServerFlags(mockSource: .onlyMock,
                                            scenario: flags.scenario,
                                            domain: flags.domain,
                                            deviceId: flags.deviceId)
        } else {
            terminalFlags = MockServerFlags(mockSource: .onlyLive,
                                            scenario: flags.scenario,
                                            domain: flags.domain,
                                            deviceId: flags.deviceId)
        }

        logger.info("modifier chain", metadata: [
            "traceUrl": .string(request.url?.absoluteString ?? ""),
            "domain": .string(flags.domain),
            "deviceId": .string(flags.deviceId),
            "path": .string(requestPath),
            "method": .string(requestMethod),
            "scenario": .string(flags.scenario ?? ""),
            "matchedIds": .string(matchedModifiers.map(\.id).joined(separator: ",")),
            "terminal": .string(terminalIsMock ? "mock" : "live")
        ])

        let chain = MockModifierChain(modifiers: matchedModifiers) { chainRequest in
            let result = try await terminal(chainRequest, terminalFlags)
            return HTTPResult(status: result.status, body: result.body, headers: result.headers)
        }

        do {
            let result = try await chain.proceed(request)
            return (status: result.status, body: result.body, headers: result.headers)
        } catch {
            logger.error("modifier chain failed, failing closed: \(error)", metadata: [
                "traceUrl": .string(request.url?.absoluteString ?? "")
            ])
            return (status: 500, body: Data(), headers: [:])
        }
    }

    func listModifiers(domain: String, deviceId: String) async throws -> [MockModifierModel] {
        let models = try await storeActor.store(for: domain).list()
        let sources = await activationStore.activeModifierSources(domain: domain, deviceId: deviceId)
        return models.map { model in
            var copy = model
            copy.source = sources[model.id]
            copy.enabled = sources[model.id] != nil
            return copy
        }
    }

    func getModifier(domain: String, id: String, deviceId: String) async throws -> MockModifierModel? {
        guard var model = try await storeActor.store(for: domain).get(id: id) else {
            return nil
        }
        let source = await activationStore.source(domain: domain, deviceId: deviceId, id: id)
        model.source = source
        model.enabled = source != nil
        return model
    }

    func createModifier(domain: String, model: MockModifierModel) async throws {
        do {
            try await storeActor.store(for: domain).create(model)
            logger.info("modifier created", metadata: [
                "modifierId": .string(model.id),
                "domain": .string(domain)
            ])
        } catch {
            throw mapModifierStoreError(error)
        }
    }

    func updateModifier(domain: String, currentId: String, model: MockModifierModel) async throws {
        let store = await storeActor.store(for: domain)
        guard currentId != model.id else {
            do {
                try store.update(currentId: currentId, with: model)
                return
            } catch {
                throw mapModifierStoreError(error)
            }
        }

        let migration = await activationStore.prepareModifierRename(
            domain: domain,
            from: currentId,
            to: model.id
        )
        do {
            try store.update(currentId: currentId, with: model)
            await activationStore.commitModifierRename(migration)
            logger.info("modifier renamed", metadata: [
                "oldModifierId": .string(currentId),
                "newModifierId": .string(model.id),
                "domain": .string(domain),
                "deviceId": .string(migration.affectedDeviceIds.joined(separator: ","))
            ])
        } catch {
            await activationStore.rollbackModifierRename(migration)
            throw mapModifierStoreError(error)
        }
    }

    func deleteModifier(domain: String, id: String) async throws {
        do {
            try await storeActor.store(for: domain).delete(id: id)
            let devices = await activationStore.removeModifierId(domain: domain, id: id)
            logger.info("modifier deleted", metadata: [
                "modifierId": .string(id),
                "domain": .string(domain),
                "deviceId": .string(devices.joined(separator: ","))
            ])
        } catch {
            throw mapModifierStoreError(error)
        }
    }

    func setActiveModifiers(domain: String, deviceId: String, activations: [MockModifierActivation]) async throws {
        var sources: [String: MockModifierPreviewSource] = [:]
        for activation in activations {
            guard sources[activation.id] == nil else {
                throw ServerMockModifierError.duplicateIds
            }
            sources[activation.id] = activation.source
        }

        let store = await storeActor.store(for: domain)
        var missing: [String] = []
        for id in sources.keys {
            if try store.get(id: id) == nil {
                missing.append(id)
            }
        }
        guard missing.isEmpty else {
            throw ServerMockModifierError.unknownIds(missing.sorted())
        }

        let diff = await activationStore.replaceActiveSources(domain: domain,
                                                              deviceId: deviceId,
                                                              sources: sources)
        for enabledId in diff.enabledIds {
            logger.info("modifier enabled", metadata: [
                "modifierId": .string(enabledId),
                "domain": .string(domain),
                "deviceId": .string(deviceId)
            ])
        }
        for disabledId in diff.disabledIds {
            logger.info("modifier disabled", metadata: [
                "modifierId": .string(disabledId),
                "domain": .string(domain),
                "deviceId": .string(deviceId)
            ])
        }
    }

    func previewModifier(
        domain: String,
        deviceId: String,
        request: MockModifierPreviewRequest,
        liveTerminal: @escaping (URLRequest) async throws -> HTTPResult
    ) async throws -> MockModifierPreviewResponse {
#if os(Linux)
        throw ServerMockModifierError.previewExecutionFailed(
            "JavaScript modifier preview is not supported on Linux"
        )
#else
        do {
            return try await previewService.execute(
                domain: domain,
                deviceId: deviceId,
                preview: request,
                liveTerminal: liveTerminal
            )
        } catch MockModifierPreviewError.invalidRequest(let message) {
            throw ServerMockModifierError.previewInvalidRequest(message)
        } catch MockModifierPreviewError.currentModifierNotFound(let id) {
            throw ServerMockModifierError.previewNotFound(id)
        } catch MockModifierPreviewError.mockNotFound(let id) {
            throw ServerMockModifierError.previewNotFound(id)
        } catch MockModifierPreviewError.conflict(let id) {
            throw ServerMockModifierError.previewConflict(id)
        } catch MockModifierPreviewError.executionFailed(let message) {
            throw ServerMockModifierError.previewExecutionFailed(message)
        } catch MockModifierPreviewError.liveRequestFailed(let message) {
            throw ServerMockModifierError.previewLiveRequestFailed(message)
        }
#endif
    }

    private func mapModifierStoreError(_ error: Error) -> Error {
        switch error {
        case MockModifierStoreError.alreadyExists(let id):
            ServerMockModifierError.alreadyExists(id)
        case MockModifierStoreError.notFound(let id):
            ServerMockModifierError.notFound(id)
        case MockModifierStoreError.invalidId(let id):
            ServerMockModifierError.invalidId(id)
        default:
            error
        }
    }
}
