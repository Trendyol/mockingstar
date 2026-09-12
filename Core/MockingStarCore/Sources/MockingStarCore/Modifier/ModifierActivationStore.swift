import CommonKit
import Foundation

/// Ephemeral per-device activation sets for modifiers.
///
/// State is process-local and intentionally lost on restart. Keys are `(domain, deviceId)` where
/// an empty `deviceId` represents the default instance shared with `/mock` when the header is omitted
/// (also what the MockingStar macOS UI toggles).
///
/// Devices that have never received an explicit `PUT /modifiers` inherit the default (`""`) set so
/// UI-activated modifiers apply to real clients that send a `DeviceId` / `deviceId` header.
/// Once a device has been configured (even with `[]`), that explicit set wins and no longer falls back.
public actor ModifierActivationStore {
    public static let shared = ModifierActivationStore()

    public struct ActivationDiff: Equatable, Sendable {
        public let enabledIds: [String]
        public let disabledIds: [String]

        public init(enabledIds: [String], disabledIds: [String]) {
            self.enabledIds = enabledIds
            self.disabledIds = disabledIds
        }
    }

    private var activeSources: [String: [String: [String: ModifierPreviewSource]]] = [:]

    public init() {}

    public func activeModifierSources(domain: String, deviceId: String) -> [String: ModifierPreviewSource] {
        let key = normalizedDeviceId(deviceId)
        let domainMap = activeSources[domain] ?? [:]
        if let specific = domainMap[key] {
            return specific
        }
        guard !key.isEmpty else { return [:] }
        return domainMap[""] ?? [:]
    }

    public func activeModifierIds(domain: String, deviceId: String) -> Set<String> {
        Set(activeModifierSources(domain: domain, deviceId: deviceId).keys)
    }

    public func source(domain: String, deviceId: String, id: String) -> ModifierPreviewSource? {
        activeModifierSources(domain: domain, deviceId: deviceId)[id]
    }

    public func isEnabled(domain: String, deviceId: String, id: String) -> Bool {
        activeModifierSources(domain: domain, deviceId: deviceId)[id] != nil
    }

    /// Atomically replaces the active set for `(domain, deviceId)`.
    @discardableResult
    public func replaceActiveSources(domain: String, deviceId: String, sources: [String: ModifierPreviewSource]) -> ActivationDiff {
        let key = normalizedDeviceId(deviceId)
        let previous = Set(activeSources[domain]?[key]?.keys ?? [:].keys)
        if activeSources[domain] == nil {
            activeSources[domain] = [:]
        }
        activeSources[domain]?[key] = sources

        let next = Set(sources.keys)
        let enabled = next.subtracting(previous).sorted()
        let disabled = previous.subtracting(next).sorted()
        return ActivationDiff(enabledIds: enabled, disabledIds: disabled)
    }

    @discardableResult
    public func replaceActiveIds(domain: String, deviceId: String, ids: Set<String>) -> ActivationDiff {
        var sources: [String: ModifierPreviewSource] = [:]
        for id in ids { sources[id] = .live }
        return replaceActiveSources(domain: domain, deviceId: deviceId, sources: sources)
    }

    /// Removes a modifier ID from every device set in the domain (used after delete).
    @discardableResult
    public func removeModifierId(domain: String, id: String) -> [String] {
        guard var domainMap = activeSources[domain] else { return [] }
        var touchedDevices: [String] = []
        for (deviceId, var sources) in domainMap {
            if sources.removeValue(forKey: id) != nil {
                domainMap[deviceId] = sources
                touchedDevices.append(deviceId)
            }
        }
        activeSources[domain] = domainMap
        return touchedDevices.sorted()
    }

    public struct ModifierRenameMigration: Equatable, Sendable {
        public let domain: String
        public let oldId: String
        public let newId: String
        public let affectedDeviceIds: [String]
    }

    public func prepareModifierRename(
        domain: String,
        from oldId: String,
        to newId: String
    ) -> ModifierRenameMigration {
        guard var domainMap = activeSources[domain] else {
            return .init(domain: domain, oldId: oldId, newId: newId, affectedDeviceIds: [])
        }
        var affected: [String] = []
        for (deviceId, sources) in domainMap {
            guard let source = sources[oldId] else { continue }
            var updated = sources
            updated[newId] = source
            domainMap[deviceId] = updated
            affected.append(deviceId)
        }
        activeSources[domain] = domainMap
        return .init(
            domain: domain,
            oldId: oldId,
            newId: newId,
            affectedDeviceIds: affected.sorted()
        )
    }

    public func commitModifierRename(_ migration: ModifierRenameMigration) {
        guard var domainMap = activeSources[migration.domain] else { return }
        for deviceId in migration.affectedDeviceIds {
            guard var sources = domainMap[deviceId] else { continue }
            sources.removeValue(forKey: migration.oldId)
            domainMap[deviceId] = sources
        }
        activeSources[migration.domain] = domainMap
    }

    public func rollbackModifierRename(_ migration: ModifierRenameMigration) {
        guard var domainMap = activeSources[migration.domain] else { return }
        for deviceId in migration.affectedDeviceIds {
            guard var sources = domainMap[deviceId] else { continue }
            if let source = sources.removeValue(forKey: migration.newId) {
                sources[migration.oldId] = source
            }
            domainMap[deviceId] = sources
        }
        activeSources[migration.domain] = domainMap
    }

    public func resetForTesting() {
        activeSources.removeAll()
    }

    private func normalizedDeviceId(_ deviceId: String) -> String {
        deviceId
    }
}
