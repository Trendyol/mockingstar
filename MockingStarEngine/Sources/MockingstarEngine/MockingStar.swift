import Foundation
import CommonKit
import MockingStarCore
#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Library entry points used by the host CLI. No executable lookup or subprocess for CRUD.
public enum MockingstarEngine {
    public static let runtimeArgument = "--mockingstar-runtime"

    public static func execute(_ input: [String]) async throws -> Any? {
        Logger.Constant.headless = true
        Logger.Constant.enableConsoleLogging = false
        do {
            let args = try CLIArguments(input)
            if args.flags.contains("version") { return ["version": "1.0.0", "schemaVersion": 1] }
            return try await MockingStar.dispatch(args)
        } catch {
            let failure = CLIOutput.normalized(error)
            throw MockingstarEngineError(code: failure.code, message: failure.message)
        }
    }

    /// Stream help, foreground readiness, or JSONL without buffering their output.
    public static func runCLI(_ input: [String]) async -> Int32 {
        Logger.Constant.headless = true
        Logger.Constant.enableConsoleLogging = false
        do {
            let args = try CLIArguments(input)
            if args.flags.contains("version") { try CLIOutput.emit(["version": "1.0.0", "schemaVersion": 1], human: args.flags.contains("human")); return 0 }
            if args.flags.contains("help") || args.words.isEmpty { print(MockingStar.help); return 0 }
            if let result = try await MockingStar.dispatch(args) { try CLIOutput.emit(result, human: args.flags.contains("human")) }
            return 0
        } catch {
            CLIOutput.failure(error, human: input.contains("--human"))
            return 1
        }
    }
}

public struct MockingstarEngineError: LocalizedError {
    public let code: String
    public let message: String
    public var errorDescription: String? { message }
}

enum MockingStar {
    static func dispatch(_ args: CLIArguments) async throws -> Any? {
        try args.validateCommand()
        let group = args.words[0]
        if group == "workspace" { return try workspaceCommand(args) }
        if group == "start" {
            var compatibility = args
            guard args.words.count == 2 else { throw WorkspaceFailure("invalid_arguments", "start PATH [--port 8008]") }
            compatibility.options["workspace"] = args.words[1]; compatibility.words = ["server", "start"]
            return try await serverCommand(CLIContext(compatibility))
        }
        if group == "analyze-usage", args.options["logs-folder"] != nil { return try legacyUsage(args) }
        let context = try CLIContext(args)
        switch group {
        case "domain": return try domainCommand(context)
        case "mock": return try await mockCommand(context)
        case "scenario": return try await scenarioCommand(context)
        case "config": return try configCommand(context)
        case "plugin": return try await pluginCommand(context)
        case "requests": return try await requestsCommand(context)
        case "server": return try await serverCommand(context)
        case "logs", "trace", "analyze-usage": return try await logsCommand(context)
        case "integrity":
            let domain = try context.domain()
            let action = try action(args)
            guard ["check", "fix"].contains(action) else { throw unknown(args) }
            let repaired = action == "fix" ? try context.workspace.fixIntegrity(domain: domain) : []
            return ["issues": try CLIOutput.object(context.workspace.integrity(domain: domain)), "repaired": try CLIOutput.object(repaired)]
        default: throw unknown(args)
        }
    }
    static func action(_ args: CLIArguments) throws -> String {
        guard args.words.count >= 2 else { throw WorkspaceFailure("invalid_arguments", "Subcommand required; use --help") }; return args.words[1]
    }
    static func unknown(_ args: CLIArguments) -> WorkspaceFailure { .init("invalid_arguments", "Unknown command: " + args.words.joined(separator: " ")) }

    static let help = """
    mockingstar — headless mock server (JSON schemaVersion 1; --human for readable output)

    Global: --workspace PATH, --domain NAME, --human. Input: --file PATH or --file -.
    workspace init|add|use|remove PATH [--name NAME]; workspace list
    domain create|list|delete --domain NAME
    mock list [--method METHOD --host HOST --path TEXT --scenario NAME --id ID]
    mock show|delete|enable|disable ID
    mock create|apply|import --file PATH [--format json|curl --fetch]
    mock update ID --file PATCH.json; mock matching ID --file RULE.json
    mock copy|move ID --to-domain NAME; mock export [ID] [--format json|curl --output PATH]
    mock reload ID [--save]
    scenario list; scenario set --device-id ID --path PATH --scenario NAME [--method METHOD]
    scenario clear --device-id ID
    config get|set [--file JSON]; config filters --file JSON; config reorder --order ID,ID
    plugin list; plugin get|set|delete --type TYPE [--common --file JS]
    plugin settings [--type TYPE --file JSON]; plugin run --type TYPE [--id ID --file JSON --message TEXT]
    requests list [--domain NAME --mock-id ID --outcome mock|live|error --since ISO8601]
    requests explain|test REQUEST_ID; requests wait --mock-id ID [--since ISO8601 --timeout 30]
    logs|trace [--follow --limit N]; analyze-usage [--logs-folder PATH --verbose]
    integrity check|fix
    server start [--port 8008 --control-port 8009 --background --record-live]
    server status|stop
    Compatibility: MockingStar; start PATH [--port PORT --logs-folder PATH --trace-export PATH]
    """
}
