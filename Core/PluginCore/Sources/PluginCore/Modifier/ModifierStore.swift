import Foundation
import CommonKit

public enum ModifierStoreError: LocalizedError {
    case alreadyExists(String)
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyExists(let id): return "Modifier '\(id)' already exists"
        case .notFound(let id): return "modifier '\(id)' not found"
        }
    }
}

public protocol ModifierStoreInterface {
    var domain: String { get }
    func list() throws -> [ModifierModel]
    func get(id: String) throws -> ModifierModel?
    func create(_ model: ModifierModel) throws
    func update(_ model: ModifierModel) throws
    func delete(id: String) throws
    func setEnabledForAll(_ enabled: Bool) throws
}

public final class ModifierStore: ModifierStoreInterface {
    public let domain: String
    private let fileManager: FileManagerInterface
    private let fileUrlBuilder: FileUrlBuilderInterface
    private let parser = ModifierParser()
    private let logger = Logger(category: "ModifierStore")

    public init(domain: String,
                fileManager: FileManagerInterface = FileManager.default,
                fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder()) {
        self.domain = domain
        self.fileManager = fileManager
        self.fileUrlBuilder = fileUrlBuilder
    }

    public func list() throws -> [ModifierModel] {
        let folder = try fileUrlBuilder.modifierFolderUrl(for: domain)
        guard fileManager.fileOrDirectoryExists(atPath: folder.path()).isExist else { return [] }
        let files = try fileManager.folderContent(at: folder).filter { $0.pathExtension == "js" }
        return files.compactMap { url in
            do {
                return try parser.parse(jsCode: try fileManager.readFile(at: url))
            } catch {
                logger.error("Modifier parse failed at \(url): \(error)")
                return nil
            }
        }
    }

    public func get(id: String) throws -> ModifierModel? {
        try list().first { $0.id == id }
    }

    public func create(_ model: ModifierModel) throws {
        let url = try fileUrlBuilder.modifierFileUrl(for: domain, id: model.id)
        guard !fileManager.fileExist(atPath: url.path()) else {
            throw ModifierStoreError.alreadyExists(model.id)
        }
        try fileManager.write(model.transformerCode, to: url)
        logger.info("Modifier created for domain \(domain), id \(model.id)")
    }

    public func update(_ model: ModifierModel) throws {
        let url = try fileUrlBuilder.modifierFileUrl(for: domain, id: model.id)
        try fileManager.write(model.transformerCode, to: url)
        logger.info("Modifier updated for domain \(domain), id \(model.id), enabled \(model.enabled)")
    }

    public func delete(id: String) throws {
        let url = try fileUrlBuilder.modifierFileUrl(for: domain, id: id)
        try fileManager.removeFile(at: url.path())
        logger.info("Modifier deleted for domain \(domain), id \(id)")
    }

    public func setEnabledForAll(_ enabled: Bool) throws {
        for model in try list() where model.enabled != enabled {
            var updated = model
            updated.enabled = enabled
            let body = extractTransformerBody(from: model.transformerCode)
            updated.transformerCode = parser.serialize(updated, transformerBody: body)
            try update(updated)
        }
        logger.info("Modifier bulk enabled \(enabled) for domain \(domain)")
    }

    private func extractTransformerBody(from code: String) -> String {
        if let range = code.range(of: "function transformer") {
            return String(code[range.lowerBound...])
        }
        return code
    }
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

    /// When `domain` is nil, enumerate Domains/*/Modifiers on disk and apply to each domain.
    public func setEnabledForAll(enabled: Bool, domain: String?) async throws {
        if let domain {
            try store(for: domain).setEnabledForAll(enabled)
            return
        }
        let builder = FileUrlBuilder()
        let domainsRoot = try builder.domainsFolderUrl()
        let fileManager = FileManager.default
        let domainDirectories = (try? fileManager.folderContent(at: domainsRoot)) ?? []
        for directory in domainDirectories {
            let name = directory.lastPathComponent
            try store(for: name).setEnabledForAll(enabled)
        }
    }
}
