import Foundation
import CommonKit
import MockingStarCore
#if os(macOS)
import PluginCore
import JavaScriptCore
#else
import PluginCoreLinux
#endif

extension MockingStar {
    static func pluginCommand(_ c: CLIContext) async throws -> Any {
        let action = try action(c.args)
        let domain = c.args.flags.contains("common") ? nil : try c.domain()
        let folder = try domain.map { try c.workspace.urls.pluginFolderUrl(for: $0) } ?? c.workspace.urls.commonPluginFolderUrl()
        if action == "list" {
            var entries: [[String: Any]] = []
            for type in PluginType.allCases {
                let domainFile = folder.appendingPathComponent(type.rawValue + ".js")
                let commonFile = try c.workspace.urls.commonPluginFolderUrl().appendingPathComponent(type.rawValue + ".js")
                entries.append(["type": type.rawValue, "domainFile": domainFile.path, "domainExists": FileManager.default.fileExists(atPath: domainFile.path), "commonExists": FileManager.default.fileExists(atPath: commonFile.path)])
            }
            if let domain {
                let plugin = await PluginCoreActor(fileUrlBuilder: c.workspace.urls, settingsRoot: c.workspace.root).pluginCore(for: domain)
                return ["plugins": entries, "configurations": try plugin.configAvailablePlugins().map { ["type": $0.pluginType.rawValue, "settings": try CLIOutput.object($0.configs)] }]
            }
            return entries
        }
        let typeName = try c.args.require("type")
        guard let type = PluginType(rawValue: typeName) else { throw WorkspaceFailure("invalid_plugin", "Unknown plugin type") }
        let file = folder.appendingPathComponent(typeName + ".js")
        guard file.resolvingSymlinksInPath().path.hasPrefix(c.workspace.root.resolvingSymlinksInPath().path + "/") else { throw WorkspaceFailure("invalid_path", "Plugin path escapes workspace") }
        switch action {
        case "get": return ["path": file.path, "source": try String(contentsOf: file, encoding: .utf8)]
        case "set":
            let data = try c.args.input()
            guard let source = String(data: data, encoding: .utf8) else { throw WorkspaceFailure("invalid_plugin", "JavaScript must be UTF-8") }
#if os(macOS)
            guard let context = JSContext() else { throw WorkspaceFailure("plugin_error", "JavaScript context unavailable") }
            context.evaluateScript(source)
            if let error = context.exception { throw WorkspaceFailure("invalid_plugin", error.toString() ?? "JavaScript failed to load") }
#endif
            try c.workspace.withLock {
                guard file.resolvingSymlinksInPath().path.hasPrefix(c.workspace.root.resolvingSymlinksInPath().path + "/") else { throw WorkspaceFailure("invalid_path", "Plugin path escapes workspace") }
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: file, options: .atomic)
            }; return ["path": file.path]
        case "delete": try c.workspace.withLock { try FileManager.default.removeItem(at: file) }; return ["deleted": file.path]
        case "settings":
            guard let domain else { throw WorkspaceFailure("invalid_arguments", "Plugin settings require --domain") }
            let file = try c.workspace.urls.configsFolderUrl(for: domain).appendingPathComponent("plugin-settings-" + typeName + ".json")
            if c.args.options["file"] != nil {
                let settings = try JSONDecoder.shared.decode([PluginConfiguration].self, from: c.args.input())
                guard Set(settings.map(\.key)).count == settings.count, settings.allSatisfy({ !$0.key.isEmpty }) else { throw WorkspaceFailure("invalid_plugin", "Setting keys must be unique and nonempty") }
                for setting in settings {
                    guard let value = setting.value else { continue }
                    let json = try JSONDecoder().decode(MatchValue.self, from: JSONEncoder().encode(value))
                    if json == .null { continue }
                    let valid: Bool
                    switch (setting.valueType, json) {
                    case (.text, .string), (.number, .number), (.bool, .bool): valid = true
                    case (.textArray, .array(let values)): valid = values.allSatisfy { $0.text != nil }
                    case (.numberArray, .array(let values)): valid = values.allSatisfy { $0.number != nil }
                    default: valid = false
                    }
                    guard valid else { throw WorkspaceFailure("invalid_plugin", "Setting \(setting.key) does not match \(setting.valueType.rawValue)") }
                }
                try c.workspace.withLock { try c.workspace.write(settings, to: file) }
            }
            let settings = FileManager.default.fileExists(atPath: file.path) ? try JSONDecoder.shared.decode([PluginConfiguration].self, from: Data(contentsOf: file)) : []
            return try CLIOutput.object(settings)
        case "run":
#if os(Linux)
            throw WorkspaceFailure("unsupported_platform", "JavaScript plugin execution requires macOS")
#else
            guard let domain else { throw WorkspaceFailure("invalid_arguments", "Plugin execution requires --domain") }
            let plugin = await PluginCoreActor(fileUrlBuilder: c.workspace.urls, settingsRoot: c.workspace.root).pluginCore(for: domain)
            switch type {
            case .mockError: return try plugin.mockErrorPlugin(message: c.args.require("message"))
            case .mockDetailMessages:
                let mock = try c.workspace.mock(id: c.id(), domain: domain)
                return ["message": try plugin.mockDetailMessagePlugin(mock: mock), "asyncMessage": try await plugin.asyncMockDetailMessagePlugin(mock: mock)]
            case .requestReloader, .liveRequestUpdater:
                let request: URLRequestModel
                if c.args.options["file"] != nil { request = try JSONDecoder().decode(URLRequestModel.self, from: c.args.input()) }
                else { let mock = try c.workspace.mock(id: c.id(), domain: domain); request = .init(url: mock.metaData.url.absoluteString, headers: try mock.requestHeader.asDictionary(), body: mock.requestBody, method: mock.metaData.method) }
                return try CLIOutput.object(type == .requestReloader ? plugin.requestReloaderPlugin(request: request) : plugin.liveRequestPlugin(request: request))
            }
#endif
        default: throw unknown(c.args)
        }
    }
}
