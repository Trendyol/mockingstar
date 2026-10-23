import Foundation
import Dispatch
import CommonKit
import MockingStarCore
import Server
import FlyingSocks
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if os(Linux)
import Glibc
#else
import Darwin
#endif

struct RuntimeRecord: Codable {
    let id: String
    let pid: Int32
    let workspace: String
    let port: UInt16
    let controlPort: UInt16
    let token: String
    let startedAt: Date
    var publicStatus: [String: Any] { ["state": "running", "id": id, "pid": pid, "workspace": workspace, "port": port, "controlPort": controlPort, "startedAt": ISO8601DateFormatter().string(from: startedAt)] }
    static func file(_ root: URL) -> URL { root.appendingPathComponent(".mockingstar/runtime.json") }
    static func read(_ root: URL) throws -> Self? {
        let file = file(root)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try JSONDecoder.shared.decode(Self.self, from: Data(contentsOf: file))
    }
    func write(_ root: URL) throws {
        let file = Self.file(root)
        try JSONEncoder.shared.encode(self).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
    func control(_ path: String) async throws -> [String: Any] {
        guard let url = URL(string: "http://127.0.0.1:\(controlPort)/\(path)") else { throw WorkspaceFailure("runtime_invalid", "Invalid control URL") }
        var request = URLRequest(url: url, timeoutInterval: 2)
        request.httpMethod = path == "stop" ? "POST" : "GET"
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("close", forHTTPHeaderField: "Connection")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, let result = try JSONSerialization.jsonObject(with: data) as? [String: Any], result["id"] as? String == id else { throw WorkspaceFailure("runtime_mismatch", "Control listener does not match workspace runtime identity") }
        return result
    }
}

actor RuntimeControl: ServerControlHandlerInterface {
    let record: RuntimeRecord
    var stopping = false
    var finished = false
    var failure: String?
    var failureCode = "start_failed"
    init(record: RuntimeRecord) { self.record = record }
    func stop() { stopping = true }
    func ended(_ error: Error? = nil) {
        finished = true; failure = error?.localizedDescription
        if case .failed(_, EADDRINUSE, _) = error as? SocketError { failureCode = "port_in_use" }
    }
    func snapshot() -> (Bool, Bool, String?) { (stopping, finished, failure) }
    func control(path: String, method: String, body: Data) async -> (status: Int, body: Data) {
        if path == "/stop", method == "POST" { stopping = true }
        else if path != "/status" || method != "GET" { return (404, Data("{}".utf8)) }
        var status = record.publicStatus
        if stopping { status["state"] = "stopping" }
        return (200, (try? JSONSerialization.data(withJSONObject: status)) ?? Data())
    }
}

/// The lifetime lock, rather than a PID check, owns a workspace instance.
final class RuntimeLock {
    private let fd: Int32
    init(root: URL) throws {
        let directory = root.appendingPathComponent(".mockingstar")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        fd = open(directory.appendingPathComponent("runtime.lock").path, O_CREAT | O_RDWR, mode_t(0o600))
        guard fd >= 0 else { throw WorkspaceFailure("lock_error", "Cannot open runtime lock") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { close(fd); throw WorkspaceFailure("already_running", "Workspace already has a managed server") }
    }
    deinit { _ = flock(fd, LOCK_UN); close(fd) }
}

extension MockingStar {
    static func serverCommand(_ c: CLIContext) async throws -> Any? {
        let action = try action(c.args), root = c.workspace.root
        if action == "status" {
            guard let record = try RuntimeRecord.read(root) else { return ["state": "stopped", "workspace": root.path] }
            if let result = try? await record.control("status") { return result }
            return ["state": "stale", "workspace": root.path, "id": record.id]
        }
        if action == "stop" {
            guard let record = try RuntimeRecord.read(root) else { return ["state": "stopped", "workspace": root.path] }
            do { _ = try await record.control("stop") }
            catch {
                // Only an unlocked record can be removed; never signal an unverified PID.
                let lock = try RuntimeLock(root: root)
                defer { withExtendedLifetime(lock) {} }
                try FileManager.default.removeItem(at: RuntimeRecord.file(root))
                return ["state": "stopped", "staleRecordRemoved": true]
            }
            let started = Date()
            while Date().timeIntervalSince(started) < 125 {
                if let current = try RuntimeRecord.read(root) {
                    if current.id != record.id { return ["state": "stopped", "id": record.id] }
                } else { return ["state": "stopped", "id": record.id] }
                try await Task.sleep(for: .milliseconds(100))
            }
            throw WorkspaceFailure("stop_timeout", "Server is still draining requests")
        }
        guard action == "start" else { throw unknown(c.args) }
        func parsePort(_ name: String, _ fallback: Double) throws -> UInt16 {
            let value = try c.args.number(name, default: fallback)
            guard (1...65535).contains(value), value.rounded() == value else { throw WorkspaceFailure("invalid_arguments", "--\(name) requires a port from 1 to 65535") }; return UInt16(value)
        }
        let port = try parsePort("port", 8008), controlPort = try parsePort("control-port", 8009)
        guard port != controlPort else { throw WorkspaceFailure("invalid_arguments", "Data and control ports must differ") }
        if c.args.flags.contains("background") { return try await startBackground(c, port: port, controlPort: controlPort) }
        if c.args.flags.contains("managed-child") { _ = setsid() }
        let lock = try RuntimeLock(root: root)
        defer { withExtendedLifetime(lock) {} }
        let record = RuntimeRecord(id: UUID().uuidString, pid: getpid(), workspace: root.path, port: port, controlPort: controlPort, token: UUID().uuidString + UUID().uuidString, startedAt: Date())
        // Stale state is replaced only after holding the lifetime lock.
        try? FileManager.default.removeItem(at: RuntimeRecord.file(root))
        let logFolder = c.args.options["logs-folder"] ?? root.appendingPathComponent(".mockingstar/logs").path
        if !FileManager.default.fileExists(atPath: logFolder) { try FileManager.default.createDirectory(atPath: logFolder, withIntermediateDirectories: true) }
        Logger.Constant.customLogFolderPath = logFolder
        Logger.Constant.traceExportPath = c.args.options["trace-export"] ?? root.appendingPathComponent(".mockingstar/trace.jsonl").path
        Logger.Constant.enableConsoleLogging = true
        let core = MockingStarCore(root: root, recordLive: c.args.flags.contains("record-live"))
        let server = Server(port: port, controlPort: controlPort, token: record.token)
        let control = RuntimeControl(record: record)
        server.registerMockHandler(core); server.registerMockSearchHandler(core); server.registerScenarioHandler(core); server.registerControlHandler(control)
        let run = Task { do { try await server.startServer(); await control.ended() } catch { await control.ended(error) } }
        let signals = [SIGINT, SIGTERM].map { number -> DispatchSourceSignal in
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .global())
            source.setEventHandler { Task { await control.stop() } }; source.resume(); return source
        }
        defer { signals.forEach { $0.cancel() }; run.cancel() }
        let started = Date()
        while !(await server.isReady()) {
            let (_, finished, failure) = await control.snapshot()
            if finished { throw WorkspaceFailure(await control.failureCode, "Server could not bind/start data port \(port) or control port \(controlPort): \(failure ?? "listener exited")") }
            if Date().timeIntervalSince(started) > 15 { await server.shutdown(timeout: 0); throw WorkspaceFailure("start_timeout", "Server listeners did not become ready") }
            try await Task.sleep(for: .milliseconds(25))
        }
        do { try record.write(root) }
        catch { await server.shutdown(timeout: 0); throw error }
        defer { if (try? RuntimeRecord.read(root)?.id) == record.id { try? FileManager.default.removeItem(at: RuntimeRecord.file(root)) } }
        try CLIOutput.emit(record.publicStatus, human: c.args.flags.contains("human"))
        while true {
            let (stop, finished, failure) = await control.snapshot()
            if stop { await server.shutdown(); break }
            if finished { if let failure { throw WorkspaceFailure("server_failed", failure) }; break }
            try await Task.sleep(for: .milliseconds(100))
        }
        await run.value
        return nil
    }

    static func startBackground(_ c: CLIContext, port: UInt16, controlPort: UInt16) async throws -> Any {
        let root = c.workspace.root
        if let existing = try RuntimeRecord.read(root), (try? await existing.control("status")) != nil { throw WorkspaceFailure("already_running", "Workspace already has a managed server") }
        let folder = root.appendingPathComponent(".mockingstar")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let process = Process()
        process.executableURL = try executableURL()
        process.arguments = [MockingstarEngine.runtimeArgument, "server", "start", "--workspace", root.path, "--port", String(port), "--control-port", String(controlPort), "--managed-child"]
        if c.args.flags.contains("record-live") { process.arguments?.append("--record-live") }
        for key in ["logs-folder", "trace-export"] { if let value = c.args.options[key] { process.arguments?.append(contentsOf: ["--" + key, value]) } }
        let stdout = folder.appendingPathComponent("server.stdout"), stderr = folder.appendingPathComponent("server.stderr")
        FileManager.default.createFile(atPath: stdout.path, contents: nil); FileManager.default.createFile(atPath: stderr.path, contents: nil)
        let out = try FileHandle(forWritingTo: stdout), err = try FileHandle(forWritingTo: stderr)
        defer { try? out.close(); try? err.close() }
        process.standardOutput = out; process.standardError = err; process.standardInput = FileHandle.nullDevice
        try process.run()
        let started = Date()
        while Date().timeIntervalSince(started) < 20 {
            if let record = try RuntimeRecord.read(root), record.pid == process.processIdentifier, let status = try? await record.control("status") { return status }
            if !process.isRunning {
                let data = (try? Data(contentsOf: stdout)) ?? Data()
                if let error = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let failure = error["error"] as? [String: String] { throw WorkspaceFailure(failure["code"] ?? "start_failed", failure["message"] ?? "Child exited") }
                throw WorkspaceFailure("start_failed", "Background server exited (\(process.terminationStatus)); inspect \(stderr.path)")
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        process.terminate()
        throw WorkspaceFailure("start_timeout", "Background server did not become ready")
    }
    static func executableURL() throws -> URL {
        if let url = Bundle.main.executableURL, FileManager.default.isExecutableFile(atPath: url.path) { return url }
        let argument = CommandLine.arguments[0]
        if argument.contains("/") { return URL(fileURLWithPath: argument).standardizedFileURL }
        for directory in (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":", omittingEmptySubsequences: false) {
            let url = URL(fileURLWithPath: directory.isEmpty ? FileManager.default.currentDirectoryPath : String(directory)).appendingPathComponent(argument)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }
        throw WorkspaceFailure("executable_not_found", "Cannot locate CLI executable for managed server")
    }
}
