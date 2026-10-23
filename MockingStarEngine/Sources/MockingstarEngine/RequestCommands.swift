import Foundation
import CommonKit
import MockingStarCore

extension MockingStar {
    static func since(_ args: CLIArguments) throws -> Date? {
        guard let text = args.options["since"] else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text) else { throw WorkspaceFailure("invalid_arguments", "--since requires an ISO8601 timestamp") }; return date
    }
    static func requestsCommand(_ c: CLIContext) async throws -> Any {
        let journal = RequestJournal(root: c.workspace.root), action = try action(c.args)
        let after = try since(c.args)
        switch action {
        case "list":
            return try CLIOutput.object(await journal.list().filter { record in
                (after == nil || record.date >= after!) && (c.args.options["domain"] == nil || c.args.options["domain"] == record.domain) && (c.args.options["mock-id"] == nil || c.args.options["mock-id"] == record.decision.mockId) && (c.args.options["outcome"] == nil || c.args.options["outcome"] == record.outcome)
            })
        case "explain": return try CLIOutput.object(await journal.read(c.id()))
        case "test":
            let record = try await journal.read(c.id())
            let decision = try await c.core.explain(request: record.request, domain: record.domain)
            return ["requestId": record.id, "networkSent": false, "decision": try CLIOutput.object(decision)]
        case "wait":
            let mockID = try c.args.require("mock-id"), timeout = try c.args.number("timeout", default: 30)
            let start = Date(), boundary = after ?? start
            while Date().timeIntervalSince(start) <= timeout {
                if let record = try await journal.list().last(where: { ($0.completedAt ?? $0.date) >= boundary && $0.outcome == "mock" && $0.status != nil && $0.error == nil && $0.decision.mockId == mockID && (c.args.options["domain"] == nil || c.args.options["domain"] == $0.domain) }) { return try CLIOutput.object(record) }
                try await Task.sleep(for: .milliseconds(100))
            }
            throw WorkspaceFailure("wait_timeout", "Mock \(mockID) was not served before timeout")
        default: throw unknown(c.args)
        }
    }
    static func logsCommand(_ c: CLIContext) async throws -> Any? {
        let group = c.args.words[0]
        if group == "analyze-usage" {
            let records = try await RequestJournal(root: c.workspace.root).list()
            var counts: [String: Int] = [:]
            for record in records where record.outcome == "mock" && record.status != nil && record.error == nil { if let id = record.decision.mockId { counts[id, default: 0] += 1 } }
            return ["total": counts.values.reduce(0, +), "mocks": counts]
        }
        let path = c.args.options["file"].map { URL(fileURLWithPath: $0) } ?? c.workspace.root.appendingPathComponent(group == "trace" ? ".mockingstar/trace.jsonl" : ".mockingstar/logs/MockingStar.log")
        let limit = try c.args.number("limit", default: 100)
        guard limit <= 100000, limit.rounded() == limit else { throw WorkspaceFailure("invalid_arguments", "--limit must be an integer up to 100000") }
        var offset = 0
        var pending = Data()
        func readLines() throws -> [String] {
            guard FileManager.default.fileExists(atPath: path.path) else { return [] }
            let handle = try FileHandle(forReadingFrom: path); defer { try? handle.close() }
            let size = try handle.seekToEnd()
            if size < offset { offset = 0; pending = Data() }
            try handle.seek(toOffset: UInt64(offset))
            pending.append(try handle.readToEnd() ?? Data()); offset = Int(size)
            var lines: [String] = []
            while let end = pending.firstIndex(of: 10) { lines.append(String(decoding: pending[..<end], as: UTF8.self)); pending.removeSubrange(...end) }
            return lines
        }
        let initial = try readLines().suffix(Int(limit))
        func value(_ line: String) -> Any { (try? JSONSerialization.jsonObject(with: Data(line.utf8))) ?? ["line": line] }
        if !c.args.flags.contains("follow") { return initial.map(value) }
        for line in initial { try CLIOutput.emit(value(line), human: c.args.flags.contains("human")) }
        while !Task.isCancelled {
            try await Task.sleep(for: .milliseconds(200))
            for line in try readLines() { try CLIOutput.emit(value(line), human: c.args.flags.contains("human")) }
        }
        return nil
    }
    static func legacyUsage(_ args: CLIArguments) throws -> Any {
        var file = URL(fileURLWithPath: try args.require("logs-folder"))
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: file.path, isDirectory: &directory) else { throw WorkspaceFailure("not_found", "Logs path not found") }
        if directory.boolValue { file.appendPathComponent("MockingStar.log") }
        var counts: [String: Int] = [:]
        for line in try String(contentsOf: file, encoding: .utf8).split(separator: "\n") where line.contains("Mock Found:") { if let id = line.split(separator: " ").last { counts[String(id), default: 0] += 1 } }
        return ["total": counts.values.reduce(0, +), "mocks": counts]
    }
}
