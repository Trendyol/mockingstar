import Foundation
import CommonKit

public enum MockModifierStoreError: LocalizedError {
    case alreadyExists(String)
    case notFound(String)
    case invalidId(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyExists(let id): return "modifier '\(id)' already exists"
        case .notFound(let id): return "modifier '\(id)' not found"
        case .invalidId(let id): return "modifier id '\(id)' is invalid"
        }
    }
}

public protocol MockModifierStoreInterface {
    var domain: String { get }
    func list() throws -> [MockModifierModel]
    func get(id: String) throws -> MockModifierModel?
    func get(ids: [String]) throws -> [MockModifierModel]
    func create(_ model: MockModifierModel) throws
    func update(currentId: String, with model: MockModifierModel) throws
    func delete(id: String) throws
}

public final class MockModifierStore: MockModifierStoreInterface {
    public let domain: String

    public init(domain: String,
                fileManager: FileManagerInterface = FileManager.default,
                fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder()) {
        self.domain = domain
    }

    public func list() throws -> [MockModifierModel] {
        []
    }

    public func get(id: String) throws -> MockModifierModel? {
        nil
    }

    public func get(ids: [String]) throws -> [MockModifierModel] {
        []
    }

    public func create(_ model: MockModifierModel) throws {}

    public func update(currentId: String, with model: MockModifierModel) throws {}

    public func delete(id: String) throws {}
}

public actor MockModifierStoreActor {
    public static let shared = MockModifierStoreActor()
    private var stores: [String: MockModifierStore] = [:]

    public func store(for domain: String) -> MockModifierStore {
        if let existing = stores[domain] { return existing }
        let created = MockModifierStore(domain: domain)
        stores[domain] = created
        return created
    }
}
