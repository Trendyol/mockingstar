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

    private var activeIds: [String: [String: Set<String>]] = [:]

    public init() {}

    public func activeModifierIds(domain: String, deviceId: String) -> Set<String> {
        let key = normalizedDeviceId(deviceId)
        let domainMap = activeIds[domain] ?? [:]
        if let specific = domainMap[key] {
            return specific
        }
        guard !key.isEmpty else { return [] }
        return domainMap[""] ?? []
    }

    public func isEnabled(domain: String, deviceId: String, id: String) -> Bool {
        activeModifierIds(domain: domain, deviceId: deviceId).contains(id)
    }

    /// Atomically replaces the active set for `(domain, deviceId)`.
    @discardableResult
    public func replaceActiveIds(domain: String, deviceId: String, ids: Set<String>) -> ActivationDiff {
        let key = normalizedDeviceId(deviceId)
        let previous = activeIds[domain]?[key] ?? []
        if activeIds[domain] == nil {
            activeIds[domain] = [:]
        }
        activeIds[domain]?[key] = ids

        let enabled = ids.subtracting(previous).sorted()
        let disabled = previous.subtracting(ids).sorted()
        return ActivationDiff(enabledIds: enabled, disabledIds: disabled)
    }

    /// Removes a modifier ID from every device set in the domain (used after delete).
    @discardableResult
    public func removeModifierId(domain: String, id: String) -> [String] {
        guard var domainMap = activeIds[domain] else { return [] }
        var touchedDevices: [String] = []
        for (deviceId, var set) in domainMap {
            if set.remove(id) != nil {
                domainMap[deviceId] = set
                touchedDevices.append(deviceId)
            }
        }
        activeIds[domain] = domainMap
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
        guard var domainMap = activeIds[domain] else {
            return .init(domain: domain, oldId: oldId, newId: newId, affectedDeviceIds: [])
        }
        var affected: [String] = []
        for (deviceId, ids) in domainMap {
            guard ids.contains(oldId) else { continue }
            var updated = ids
            updated.insert(newId)
            domainMap[deviceId] = updated
            affected.append(deviceId)
        }
        activeIds[domain] = domainMap
        return .init(
            domain: domain,
            oldId: oldId,
            newId: newId,
            affectedDeviceIds: affected.sorted()
        )
    }

    public func commitModifierRename(_ migration: ModifierRenameMigration) {
        guard var domainMap = activeIds[migration.domain] else { return }
        for deviceId in migration.affectedDeviceIds {
            guard var ids = domainMap[deviceId] else { continue }
            ids.remove(migration.oldId)
            domainMap[deviceId] = ids
        }
        activeIds[migration.domain] = domainMap
    }

    public func rollbackModifierRename(_ migration: ModifierRenameMigration) {
        guard var domainMap = activeIds[migration.domain] else { return }
        for deviceId in migration.affectedDeviceIds {
            guard var ids = domainMap[deviceId] else { continue }
            ids.remove(migration.newId)
            ids.insert(migration.oldId)
            domainMap[deviceId] = ids
        }
        activeIds[migration.domain] = domainMap
    }

    public func resetForTesting() {
        activeIds.removeAll()
    }

    private func normalizedDeviceId(_ deviceId: String) -> String {
        deviceId
    }
}
