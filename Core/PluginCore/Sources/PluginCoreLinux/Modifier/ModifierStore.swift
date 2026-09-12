import Foundation
import CommonKit

public enum ModifierStoreError: LocalizedError {
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

public protocol ModifierStoreInterface {
    var domain: String { get }
    func list() throws -> [ModifierModel]
    func get(id: String) throws -> ModifierModel?
    func get(ids: [String]) throws -> [ModifierModel]
    func create(_ model: ModifierModel) throws
    func update(currentId: String, with model: ModifierModel) throws
    func delete(id: String) throws
}

public final class ModifierStore: ModifierStoreInterface {
    public let domain: String

    public init(domain: String,
                fileManager: FileManagerInterface = FileManager.default,
                fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder()) {
        self.domain = domain
    }

    public func list() throws -> [ModifierModel] {
        []
    }

    public func get(id: String) throws -> ModifierModel? {
        nil
    }

    public func get(ids: [String]) throws -> [ModifierModel] {
        []
    }

    public func create(_ model: ModifierModel) throws {}

    public func update(currentId: String, with model: ModifierModel) throws {}

    public func delete(id: String) throws {}
}

public actor ModifierStoreActor {
    public static let shared = ModifierStoreActor()
    private var stores: [String: ModifierStore] = [:]

    public func store(for domain: String) -> ModifierStore {
        if let existing = stores[domain] { return existing }
        let created = ModifierStore(domain: domain)
        stores[domain] = created
        return created
    }
}
