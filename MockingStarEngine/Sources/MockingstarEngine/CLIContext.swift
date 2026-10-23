import Foundation
import CommonKit
import MockingStarCore
#if os(Linux)
import Glibc
#else
import Darwin
#endif

struct CLIArguments {
    var words: [String] = []
    var options: [String: String] = [:]
    var flags: Set<String> = []
    static let valueOptions: Set<String> = ["workspace", "domain", "file", "name", "id", "mock-id", "method", "host", "path", "scenario", "device-id", "to-domain", "format", "output", "port", "control-port", "timeout", "since", "limit", "logs-folder", "trace-export", "type", "message", "order", "outcome"]
    static let flagOptions: Set<String> = ["human", "background", "record-live", "save", "fetch", "common", "follow", "verbose", "managed-child", "help", "version"]
    init(_ input: [String]) throws {
        var i = 0
        while i < input.count {
            var token = input[i]
            if token == "--" { words += input.dropFirst(i + 1); break }
            if token == "-h" { token = "--help" }
            if token == "-p" { token = "--port" }; if token == "-l" { token = "--logs-folder" }; if token == "-v" { token = "--verbose" }
            if token.hasPrefix("--") {
                let pair = token.dropFirst(2).split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
                let key = pair[0]
                if Self.flagOptions.contains(key) {
                    guard pair.count == 1 else { throw WorkspaceFailure("invalid_arguments", "Flag --\(key) takes no value") }; flags.insert(key)
                } else {
                    guard Self.valueOptions.contains(key) else { throw WorkspaceFailure("invalid_arguments", "Unknown option --\(key)") }
                    let value: String
                    if pair.count == 2 { value = pair[1] }
                    else { i += 1; guard i < input.count, !input[i].hasPrefix("--") else { throw WorkspaceFailure("invalid_arguments", "--\(key) requires a value") }; value = input[i] }
                    guard options[key] == nil else { throw WorkspaceFailure("invalid_arguments", "Repeated option --\(key)") }; options[key] = value
                }
            } else if token.hasPrefix("-") { throw WorkspaceFailure("invalid_arguments", "Unknown option \(token)") }
            else { words.append(token) }
            i += 1
        }
    }
    func require(_ key: String) throws -> String {
        guard let value = options[key], !value.isEmpty else { throw WorkspaceFailure("invalid_arguments", "--\(key) is required") }; return value
    }
    func number(_ key: String, default fallback: Double) throws -> Double {
        guard let value = options[key] else { return fallback }
        guard let number = Double(value), number.isFinite, number >= 0 else { throw WorkspaceFailure("invalid_arguments", "--\(key) requires a nonnegative number") }; return number
    }
    func input() throws -> Data {
        let path = try require("file")
        if path == "-" { return FileHandle.standardInput.readDataToEndOfFile() }
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }
    func validateCommand() throws {
        let group = words.first ?? "", action = words.count > 1 ? words[1] : ""
        var allowed: Set<String> = ["workspace", "human", "help"]
        var count = 2...2
        func allow(_ names: String) { allowed.formUnion(names.split(separator: " ").map(String.init)) }
        switch group {
        case "workspace":
            guard ["init", "add", "use", "remove", "list"].contains(action) else { throw MockingStar.unknown(self) }
            if action != "list" { count = 2...3; allow("name") }
        case "domain":
            guard ["create", "delete", "list"].contains(action) else { throw MockingStar.unknown(self) }; allow("domain")
        case "mock":
            allow("domain")
            switch action {
            case "list": allow("id method host path scenario")
            case "show", "delete", "enable", "disable": count = 2...3; allow("id")
            case "create", "apply", "import": allow("file format fetch")
            case "update", "matching": count = 2...3; allow("id file")
            case "copy", "move": count = 2...3; allow("id to-domain")
            case "export": count = 2...3; allow("id format output")
            case "reload": count = 2...3; allow("id save")
            default: throw MockingStar.unknown(self)
            }
        case "scenario":
            allow("domain")
            switch action { case "list": break; case "set": allow("device-id path scenario method"); case "clear": allow("device-id"); default: throw MockingStar.unknown(self) }
        case "config":
            allow("domain")
            switch action { case "get": break; case "set", "filters": allow("file"); case "reorder": allow("order"); default: throw MockingStar.unknown(self) }
        case "plugin":
            allow("domain common type")
            switch action { case "list", "get", "delete": break; case "set", "settings": allow("file"); case "run": count = 2...3; allow("id file message"); default: throw MockingStar.unknown(self) }
        case "requests":
            switch action {
            case "list": allow("domain mock-id outcome since")
            case "explain", "test": count = 2...3; allow("id")
            case "wait": allow("domain mock-id since timeout")
            default: throw MockingStar.unknown(self)
            }
        case "server":
            switch action { case "status", "stop": break; case "start": allow("port control-port background record-live managed-child logs-folder trace-export verbose"); default: throw MockingStar.unknown(self) }
        case "integrity":
            guard ["check", "fix"].contains(action) else { throw MockingStar.unknown(self) }; allow("domain")
        case "logs", "trace": count = 1...1; allow("file follow limit")
        case "analyze-usage": count = 1...1; allow("logs-folder verbose")
        case "start": allow("port control-port background record-live logs-folder trace-export verbose")
        default: throw MockingStar.unknown(self)
        }
        guard count.contains(words.count) else { throw WorkspaceFailure("invalid_arguments", "Unexpected or missing positional arguments") }
        let unexpected = Set(options.keys).union(flags).subtracting(allowed).sorted()
        guard unexpected.isEmpty else { throw WorkspaceFailure("invalid_arguments", "Options not accepted by this command: " + unexpected.map { "--" + $0 }.joined(separator: ", ")) }
        if words.count == 3 && options["id"] != nil { throw WorkspaceFailure("invalid_arguments", "Specify ID once") }
    }
}

struct WorkspaceRegistry: Codable {
    struct Entry: Codable { var name: String; var path: String }
    var selected: String?
    var workspaces: [Entry] = []
    static var file: URL {
        let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) } ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
        return base.appendingPathComponent("mockingstar/workspaces.json")
    }
    static func read() throws -> Self {
        guard FileManager.default.fileExists(atPath: file.path) else { return .init() }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: file))
    }
    mutating func save() throws {
        try FileManager.default.createDirectory(at: Self.file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(self).write(to: Self.file, options: .atomic)
    }
}

struct CLIContext {
    let args: CLIArguments
    let workspace: MockWorkspace
    init(_ args: CLIArguments) throws {
        self.args = args
        guard let path = try args.options["workspace"] ?? WorkspaceRegistry.read().selected else { throw WorkspaceFailure("workspace_required", "Use --workspace PATH or workspace use PATH") }
        let root = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Domains").path) else { throw WorkspaceFailure("workspace_not_found", "Initialize workspace first: \(root.path)") }
        workspace = MockWorkspace(root: root)
    }
    var core: MockingStarCore { MockingStarCore(root: workspace.root, recordLive: false) }
    func domain() throws -> String { let value = try args.require("domain"); try workspace.checkDomain(value); return value }
    func id(_ offset: Int = 2) throws -> String {
        if let id = args.options["id"] { return id }
        guard args.words.count > offset else { throw WorkspaceFailure("invalid_arguments", "Mock/request ID is required") }; return args.words[offset]
    }
}

enum CLIOutput {
    static func object<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder.shared.encode(value), options: .fragmentsAllowed)
    }
    static func emit(_ data: Any, human: Bool = false) throws {
        let result: [String: Any] = ["schemaVersion": 1, "ok": true, "data": data]
        let bytes = try JSONSerialization.data(withJSONObject: human ? data : result, options: human ? [.prettyPrinted, .sortedKeys, .fragmentsAllowed] : [.sortedKeys, .fragmentsAllowed])
        FileHandle.standardOutput.write(bytes); FileHandle.standardOutput.write(Data("\n".utf8))
    }
    static func normalized(_ error: Error) -> WorkspaceFailure {
        let failure: WorkspaceFailure
        if let value = error as? WorkspaceFailure { failure = value }
        else if error is DecodingError || error is MockMatchingError { failure = .init("invalid_input", error.localizedDescription) }
        else if let value = error as? URLError { failure = .init("network_error", value.localizedDescription) }
        else { failure = .init("operation_failed", error.localizedDescription) }
        return failure
    }
    static func failure(_ error: Error, human: Bool = false) {
        let failure = normalized(error)
        if human { FileHandle.standardError.write(Data("\(failure.code): \(failure.message)\n".utf8)) }
        else {
            let value: [String: Any] = ["schemaVersion": 1, "ok": false, "error": ["code": failure.code, "message": failure.message]]
            if var bytes = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) { bytes.append(10); FileHandle.standardOutput.write(bytes) }
        }
    }
}
