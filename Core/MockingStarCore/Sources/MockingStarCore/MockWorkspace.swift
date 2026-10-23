import Foundation
import CommonKit
#if os(Linux)
import Glibc
#else
import Darwin
#endif

public struct WorkspaceFailure: Error, LocalizedError {
    public let code: String
    public let message: String
    public var errorDescription: String? { message }
    public init(_ code: String, _ message: String) { self.code = code; self.message = message }
}

public struct IntegrityIssue: Codable {
    public var kind: String
    public var path: String
    public var mockId: String?
    public var message: String
}

/// File operations are shared by the CLI and server; writers serialize across processes.
public final class MockWorkspace {
    public let root: URL
    public let urls: FileUrlBuilder
    public init(root: URL) {
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
        self.urls = FileUrlBuilder(root: self.root)
    }
    public func initialize() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Domains"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Plugins"), withIntermediateDirectories: true)
    }
    public func checkDomain(_ domain: String) throws {
        guard !domain.isEmpty, domain != ".", domain != "..", !domain.contains("/"), !domain.contains("\\"), !domain.contains("\0") else {
            throw WorkspaceFailure("invalid_domain", "Domain must be a single directory name")
        }
        try checkContained(root.appendingPathComponent("Domains").appendingPathComponent(domain))
    }
    public func domains() throws -> [String] {
        let folder = root.appendingPathComponent("Domains")
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }.map(\.lastPathComponent).sorted()
    }
    public func createDomain(_ domain: String) throws {
        try checkDomain(domain)
        try FileStructureHelper(root: root).createDomainFileStructure(mockDomain: domain)
        let config = try urls.configUrl(for: domain)
        if !FileManager.default.fileExists(atPath: config.path) { try write(ConfigModel(), to: config) }
    }
    public func removeDomain(_ domain: String) throws {
        try checkDomain(domain)
        try withLock { try FileManager.default.removeItem(at: urls.domainFolder(for: domain)) }
    }
    public func files(domain: String) throws -> [URL] {
        try checkDomain(domain)
        let folder = try urls.mocksFolderUrl(for: domain)
        guard let e = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        let files = e.compactMap { $0 as? URL }.filter { $0.pathExtension == "json" }
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() }.sorted { $0.path < $1.path }
        for file in files { try checkContained(file) }
        return files
    }
    public func read(_ file: URL) throws -> MockModel {
        try checkContained(file)
        let model = try JSONDecoder.shared.decode(MockModel.self, from: Data(contentsOf: file))
        model.fileURL = file
        return model
    }
    public func mocks(domain: String) throws -> [MockModel] { try files(domain: domain).map(read) }
    public func mock(id: String, domain: String) throws -> MockModel {
        let matches = try mocks(domain: domain).filter { $0.id == id }
        guard matches.count == 1 else { throw WorkspaceFailure(matches.isEmpty ? "not_found" : "duplicate_id", "Expected one mock with ID \(id); found \(matches.count)") }
        return matches[0]
    }
    public func validate(_ mock: MockModel) throws {
        guard !mock.id.isEmpty, !mock.id.contains("/"), !mock.id.contains("\\"), !mock.id.contains("\0"), ["http", "https"].contains(mock.metaData.url.scheme?.lowercased() ?? ""), mock.metaData.url.host != nil,
              MockMatching.isHTTPToken(mock.metaData.method), (100...599).contains(mock.metaData.httpStatus), mock.metaData.responseTime.isFinite, mock.metaData.responseTime >= 0 else {
            throw WorkspaceFailure("invalid_mock", "Mock requires an ID, HTTP(S) URL, method, valid HTTP status and nonnegative delay")
        }
        for headers in [try mock.requestHeader.asDictionary(), try mock.responseHeader.asDictionary()] {
            guard headers.allSatisfy({ MockMatching.isHTTPToken($0.key) && $0.value.unicodeScalars.allSatisfy { $0.value != 0 && $0.value != 10 && $0.value != 13 } }) else {
                throw WorkspaceFailure("invalid_mock", "Header names must be HTTP tokens and values must not contain control line breaks")
            }
        }
        try mock.matching?.validate()
        _ = try JSONEncoder.shared.encode(mock)
    }
    public func apply(_ incoming: [MockModel], domain: String) throws {
        try checkDomain(domain)
        for mock in incoming { try validate(mock); _ = try targetURL(mock, domain: domain) }
        guard Set(incoming.map(\.id)).count == incoming.count else { throw WorkspaceFailure("duplicate_id", "Bundle contains duplicate IDs") }
        try withLock {
            try createDomain(domain)
            let existing = try mocks(domain: domain)
            guard Set(existing.map(\.id)).count == existing.count else { throw WorkspaceFailure("duplicate_id", "Repair existing duplicate IDs before applying mocks") }
            var targets: [(URL, Data)] = []
            var obsolete: [URL] = []
            for mock in incoming {
                let target = try targetURL(mock, domain: domain)
                if targets.contains(where: { $0.0 == target }) { throw WorkspaceFailure("conflict", "Bundle mocks resolve to the same file: \(target.path)") }
                if let old = existing.first(where: { $0.id == mock.id })?.fileURL, old != target { obsolete.append(old) }
                if existing.contains(where: { $0.fileURL == target && $0.id != mock.id }) { throw WorkspaceFailure("conflict", "A different mock occupies \(target.path)") }
                targets.append((target, try JSONEncoder.shared.encode(mock)))
            }
            let touched = Set(targets.map { $0.0 } + obsolete)
            let backups = Dictionary(uniqueKeysWithValues: touched.compactMap { url -> (URL, Data)? in (try? Data(contentsOf: url)).map { (url, $0) } })
            do {
                for (url, data) in targets {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: url, options: .atomic)
                }
                for old in obsolete where !targets.contains(where: { $0.0 == old }) { try FileManager.default.removeItem(at: old) }
            } catch {
                for url in touched {
                    if let data = backups[url] { try? data.write(to: url, options: .atomic) }
                    else { try? FileManager.default.removeItem(at: url) }
                }
                throw error
            }
        }
    }
    public func delete(ids: [String], domain: String) throws {
        try withLock {
            let targets = try ids.map { try mock(id: $0, domain: domain).fileURL! }
            for target in targets { try FileManager.default.removeItem(at: target) }
        }
    }
    public func config(domain: String) throws -> ConfigModel {
        try checkDomain(domain)
        return try JSONDecoder.shared.decode(ConfigModel.self, from: Data(contentsOf: urls.configUrl(for: domain)))
    }
    public func setConfig(_ config: ConfigModel, domain: String) throws {
        try checkDomain(domain)
        guard config.appFilterConfigs.pathMatchingRatio.isFinite, (0...1).contains(config.appFilterConfigs.pathMatchingRatio) else {
            throw WorkspaceFailure("invalid_config", "pathMatchingRatio must be between zero and one")
        }
        try withLock { try createDomain(domain); try write(config, to: urls.configUrl(for: domain)) }
    }
    public func integrity(domain: String) throws -> [IntegrityIssue] {
        var issues: [IntegrityIssue] = []; var ids: [String: [URL]] = [:]
        for file in try files(domain: domain) {
            let start = Date()
            do {
                let mock = try read(file)
                ids[mock.id, default: []].append(file)
                if !file.path.hasSuffix("/" + mock.filePath) { issues.append(.init(kind: "wrong_path", path: file.path, mockId: mock.id, message: mock.filePath)) }
                do { try validate(mock) } catch { issues.append(.init(kind: "invalid_mock", path: file.path, mockId: mock.id, message: error.localizedDescription)) }
                if Date().timeIntervalSince(start) > 0.5 { issues.append(.init(kind: "slow_read", path: file.path, mockId: mock.id, message: "Read exceeded 0.5 seconds")) }
            } catch { issues.append(.init(kind: "invalid_file", path: file.path, message: error.localizedDescription)) }
        }
        for (id, files) in ids where files.count > 1 {
            issues += files.map { .init(kind: "duplicate_id", path: $0.path, mockId: id, message: "Duplicate ID") }
        }
        return issues
    }
    public func fixIntegrity(domain: String) throws -> [IntegrityIssue] {
        try withLock {
            let issues = try integrity(domain: domain)
            var seen: Set<String> = []
            let ordered = try files(domain: domain).sorted { a, b in
                let aCorrect = (try? read(a)).map { a.path.hasSuffix("/" + $0.filePath) } ?? false
                let bCorrect = (try? read(b)).map { b.path.hasSuffix("/" + $0.filePath) } ?? false
                return aCorrect == bCorrect ? a.path < b.path : aCorrect
            }
            for file in ordered {
                guard let mock = try? read(file) else { continue }
                guard (try? validate(mock)) != nil else { continue }
                if !seen.insert(mock.id).inserted { mock.metaData.id = UUID().uuidString }
                guard let target = try? targetURL(mock, domain: domain) else { continue }
                if target != file && FileManager.default.fileExists(atPath: target.path) { continue }
                try write(mock, to: target)
                if target != file { try FileManager.default.removeItem(at: file) }
            }
            return issues
        }
    }
    public func write<T: Encodable>(_ value: T, to url: URL) throws {
        try checkContained(url)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.shared.encode(value).write(to: url, options: .atomic)
    }
    private func checkContained(_ url: URL) throws {
        guard url.standardizedFileURL.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else {
            throw WorkspaceFailure("invalid_path", "Path escapes workspace")
        }
    }
    private func targetURL(_ mock: MockModel, domain: String) throws -> URL {
        let folder = try urls.mocksFolderUrl(for: domain)
        let target = folder.appendingPathComponent(mock.filePath).standardizedFileURL.resolvingSymlinksInPath()
        try checkContained(target)
        guard target.path.hasPrefix(folder.standardizedFileURL.resolvingSymlinksInPath().path + "/") else {
            throw WorkspaceFailure("invalid_path", "Mock path escapes its domain's Mocks directory")
        }
        return target
    }
    public func withLock<T>(_ body: () throws -> T) throws -> T {
        let folder = root.appendingPathComponent(".mockingstar")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fd = open(folder.appendingPathComponent("write.lock").path, O_CREAT | O_RDWR, mode_t(0o600))
        guard fd >= 0 else { throw WorkspaceFailure("lock_error", "Cannot open workspace lock") }
        defer { _ = flock(fd, LOCK_UN); close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw WorkspaceFailure("lock_error", "Cannot lock workspace") }
        return try body()
    }
}

actor RuleIndex {
    private let workspace: MockWorkspace
    private var domainCaches: [String: [String: (stamp: String, mock: MockModel)]] = [:]
    private var rejected: [String: [MatchCandidate]] = [:]
    private let logger = Logger(category: "RuleIndex")
    init(root: URL) { workspace = MockWorkspace(root: root) }
    func mocks(domain: String) throws -> [MockModel] {
        return try workspace.withLock {
        let files = try workspace.files(domain: domain)
        let paths = Set(files.map(\.path))
        var cache = (domainCaches[domain] ?? [:]).filter { paths.contains($0.key) }
        var failures: [MatchCandidate] = []
        for file in files {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            let stamp = "\((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0):\(attributes[.size] ?? ""):\(attributes[.systemFileNumber] ?? "")"
            if cache[file.path]?.stamp == stamp { continue }
            do {
                let mock = try workspace.read(file)
                if mock.matching != nil { try workspace.validate(mock) }
                cache[file.path] = (stamp, mock)
            } catch {
                logger.error("Rule reload rejected", metadata: ["path": .string(file.path), "reason": .string(error.localizedDescription)])
                if cache[file.path] == nil { failures.append(.init(mockId: file.lastPathComponent, priority: 0, matched: false, failures: [.init(field: "file", reason: "mock_load_failed: " + error.localizedDescription, actual: .string(file.path))])) }
            }
        }
        domainCaches[domain] = cache
        rejected[domain] = failures
        return cache.keys.sorted().compactMap { cache[$0]?.mock }
        }
    }
    func failures(domain: String) -> [MatchCandidate] { rejected[domain] ?? [] }
}
