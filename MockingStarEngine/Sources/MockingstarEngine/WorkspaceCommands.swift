import Foundation
import CommonKit
import MockingStarCore

extension MockingStar {
    static func workspaceCommand(_ args: CLIArguments) throws -> Any {
        let action = try action(args)
        var registry = try WorkspaceRegistry.read()
        if action == "list" { return try CLIOutput.object(registry) }
        guard ["init", "add", "use", "remove"].contains(action) else { throw unknown(args) }
        guard let input = args.options["workspace"] ?? args.words.dropFirst(2).first else { throw WorkspaceFailure("invalid_arguments", "Workspace path required") }
        let path = URL(fileURLWithPath: input).standardizedFileURL.path
        let workspace = MockWorkspace(root: URL(fileURLWithPath: path))
        if action == "init" { try workspace.initialize() }
        if action != "remove" {
            guard FileManager.default.fileExists(atPath: workspace.root.appendingPathComponent("Domains").path) else { throw WorkspaceFailure("workspace_not_found", "No workspace at \(path)") }
            registry.workspaces.removeAll { $0.path == path }
            registry.workspaces.append(.init(name: args.options["name"] ?? workspace.root.lastPathComponent, path: path))
            if action == "use" || registry.selected == nil { registry.selected = path }
        } else { registry.workspaces.removeAll { $0.path == path }; if registry.selected == path { registry.selected = nil } }
        try registry.save(); return try CLIOutput.object(registry)
    }
    static func domainCommand(_ c: CLIContext) throws -> Any {
        switch try action(c.args) {
        case "list": return try c.workspace.domains()
        case "create": let domain = try c.domain(); try c.workspace.createDomain(domain); return ["domain": domain]
        case "delete": let domain = try c.domain(); try c.workspace.removeDomain(domain); return ["deleted": domain]
        default: throw unknown(c.args)
        }
    }
    static func configCommand(_ c: CLIContext) throws -> Any {
        let domain = try c.domain(), action = try action(c.args)
        if action == "get" { return try CLIOutput.object(c.workspace.config(domain: domain)) }
        let config: ConfigModel
        switch action {
        case "set": config = try JSONDecoder.shared.decode(ConfigModel.self, from: c.args.input())
        case "filters": config = try c.workspace.config(domain: domain); config.mockFilterConfigs = try JSONDecoder.shared.decode([MockFilterConfigModel].self, from: c.args.input())
        case "reorder":
            config = try c.workspace.config(domain: domain)
            let ids = try c.args.require("order").split(separator: ",").map(String.init)
            guard ids.count == config.mockFilterConfigs.count, Set(ids).count == ids.count, Set(ids) == Set(config.mockFilterConfigs.map(\.id)) else { throw WorkspaceFailure("invalid_order", "Order must contain each filter ID once") }
            config.mockFilterConfigs = ids.compactMap { id in config.mockFilterConfigs.first { $0.id == id } }
        default: throw unknown(c.args)
        }
        try c.workspace.setConfig(config, domain: domain); return try CLIOutput.object(config)
    }
    static func scenarioCommand(_ c: CLIContext) async throws -> Any {
        let domain = try c.domain(), action = try action(c.args), core = c.core
        if action == "list" { return try CLIOutput.object(await core.listScenarios(domain: domain)) }
        guard ["set", "clear"].contains(action) else { throw unknown(c.args) }
        let scenario = ScenarioModel(deviceId: try c.args.require("device-id"), path: action == "set" ? try c.args.require("path") : "", method: c.args.options["method"], scenario: action == "set" ? try c.args.require("scenario") : "", mockDomain: domain)
        if action == "set" { try await core.addScenario(scenario: scenario) }
        else { try await core.removeScenario(scenario: scenario) }
        return try CLIOutput.object(await core.listScenarios(domain: domain))
    }
}
