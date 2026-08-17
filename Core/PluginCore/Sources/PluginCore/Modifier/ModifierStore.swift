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
            let filenameId = url.deletingPathExtension().lastPathComponent
            do {
                return try parser.parse(jsCode: try fileManager.readFile(at: url), filenameId: filenameId)
            } catch {
                logger.error("Modifier parse failed at \(url): \(error)")
                return nil
            }
        }
    }

    public func get(id: String) throws -> ModifierModel? {
        try validateId(id)
        let url = try fileUrlBuilder.modifierFileUrl(for: domain, id: id)
        guard fileManager.fileExist(atPath: url.path()) else { return nil }
        return try parser.parse(jsCode: try fileManager.readFile(at: url), filenameId: id)
    }

    /// Loads only the requested modifier files by filename. Missing IDs are omitted.
    public func get(ids: [String]) throws -> [ModifierModel] {
        var result: [ModifierModel] = []
        result.reserveCapacity(ids.count)
        for id in ids {
            if let model = try get(id: id) {
                result.append(model)
            }
        }
        return result
    }

    public func create(_ model: ModifierModel) throws {
        try validateId(model.id)
        let url = try fileUrlBuilder.modifierFileUrl(for: domain, id: model.id)
        guard !fileManager.fileExist(atPath: url.path()) else {
            throw ModifierStoreError.alreadyExists(model.id)
        }
        try fileManager.write(parser.serialize(model), to: url)
        logger.info("Modifier created", metadata: [
            "modifierId": .string(model.id),
            "domain": .string(domain)
        ])
    }

    public func update(currentId: String, with model: ModifierModel) throws {
        try validateId(currentId)
        try validateId(model.id)

        let currentURL = try fileUrlBuilder.modifierFileUrl(for: domain, id: currentId)
        guard fileManager.fileExist(atPath: currentURL.path()) else {
            throw ModifierStoreError.notFound(currentId)
        }

        if currentId == model.id {
            try fileManager.write(parser.serialize(model), to: currentURL)
            logger.info("modifier updated", metadata: [
                "modifierId": .string(model.id),
                "domain": .string(domain)
            ])
            return
        }

        let targetURL = try fileUrlBuilder.modifierFileUrl(for: domain, id: model.id)
        guard !fileManager.fileExist(atPath: targetURL.path()) else {
            throw ModifierStoreError.alreadyExists(model.id)
        }

        let originalContent = try fileManager.readFile(at: currentURL)
        do {
            try fileManager.write(parser.serialize(model), to: currentURL)
            try fileManager.moveFile(from: currentURL.path(), to: targetURL.path())
        } catch {
            if fileManager.fileExist(atPath: targetURL.path()) {
                try? fileManager.moveFile(from: targetURL.path(), to: currentURL.path())
            }
            if fileManager.fileExist(atPath: currentURL.path()) {
                try? fileManager.write(originalContent, to: currentURL)
            }
            throw error
        }
    }

    public func delete(id: String) throws {
        try validateId(id)
        let url = try fileUrlBuilder.modifierFileUrl(for: domain, id: id)
        guard fileManager.fileExist(atPath: url.path()) else {
            throw ModifierStoreError.notFound(id)
        }
        try fileManager.removeFile(at: url.path())
        logger.info("modifier deleted", metadata: [
            "modifierId": .string(id),
            "domain": .string(domain)
        ])
    }

    private func validateId(_ id: String) throws {
        do {
            try ModifierParser.validateModifierId(id)
        } catch {
            throw ModifierStoreError.invalidId(id)
        }
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
}
