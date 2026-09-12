import Foundation

public protocol APIKeyStoreInterface {
    func load() -> String?
    func save(_ key: String) throws
    func clear() throws
}

/// Persists the GenAI Gateway API key in `UserDefaults` (no Keychain permission prompts).
public struct UserDefaultsAPIKeyStore: APIKeyStoreInterface {
    public static let defaultKey = "modifierGenAIGatewayAPIKey"

    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = UserDefaultsAPIKeyStore.defaultKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> String? {
        guard let value = defaults.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    public func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: self.key)
        } else {
            defaults.set(trimmed, forKey: self.key)
        }
    }

    public func clear() throws {
        defaults.removeObject(forKey: key)
    }
}

public final class InMemoryAPIKeyStore: APIKeyStoreInterface {
    private var value: String?

    public init(value: String? = nil) {
        self.value = value
    }

    public func load() -> String? { value }

    public func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        value = trimmed.isEmpty ? nil : trimmed
    }

    public func clear() throws {
        value = nil
    }
}
