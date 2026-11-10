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
    private let fileManager: FileManagerInterface
    private let fileUrlBuilder: FileUrlBuilderInterface
    private let parser = MockModifierParser()
    private let logger = Logger(category: "MockModifierStore")

    public init(domain: String,
                fileManager: FileManagerInterface = FileManager.default,
                fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder()) {
        self.domain = domain
        self.fileManager = fileManager
        self.fileUrlBuilder = fileUrlBuilder
    }

    public func list() throws -> [MockModifierModel] {
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

    public func get(id: String) throws -> MockModifierModel? {
        try validateId(id)
        let url = try fileUrlBuilder.modifierFileUrl(for: domain, id: id)
        guard fileManager.fileExist(atPath: url.path()) else { return nil }
        return try parser.parse(jsCode: try fileManager.readFile(at: url), filenameId: id)
    }

    /// Loads only the requested modifier files by filename. Missing IDs are omitted.
    public func get(ids: [String]) throws -> [MockModifierModel] {
        var result: [MockModifierModel] = []
        result.reserveCapacity(ids.count)
        for id in ids {
            if let model = try get(id: id) {
                result.append(model)
            }
        }
        return result
    }

    public func create(_ model: MockModifierModel) throws {
        try validateId(model.id)
        let url = try fileUrlBuilder.modifierFileUrl(for: domain, id: model.id)
        guard !fileManager.fileExist(atPath: url.path()) else {
            throw MockModifierStoreError.alreadyExists(model.id)
        }
        try fileManager.write(parser.serialize(model), to: url)
        logger.info("Modifier created", metadata: [
            "modifierId": .string(model.id),
            "domain": .string(domain)
        ])
    }

    public func update(currentId: String, with model: MockModifierModel) throws {
        try validateId(currentId)
        try validateId(model.id)

        let currentURL = try fileUrlBuilder.modifierFileUrl(for: domain, id: currentId)
        guard fileManager.fileExist(atPath: currentURL.path()) else {
            throw MockModifierStoreError.notFound(currentId)
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
            throw MockModifierStoreError.alreadyExists(model.id)
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
            throw MockModifierStoreError.notFound(id)
        }
        try fileManager.removeFile(at: url.path())
        logger.info("modifier deleted", metadata: [
            "modifierId": .string(id),
            "domain": .string(domain)
        ])
    }

    private func validateId(_ id: String) throws {
        do {
            try MockModifierParser.validateModifierId(id)
        } catch {
            throw MockModifierStoreError.invalidId(id)
        }
    }
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
