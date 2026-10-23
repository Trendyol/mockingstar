import Foundation
import CommonKit
import MockingStarCore

extension MockingStar {
    static func mockCommand(_ c: CLIContext) async throws -> Any {
        let domain = try c.domain(), action = try action(c.args)
        switch action {
        case "list":
            let mocks = try c.workspace.mocks(domain: domain).filter { mock in
                let a = c.args.options
                return (a["id"] == nil || a["id"] == mock.id) && (a["method"] == nil || a["method"]?.uppercased() == mock.metaData.method.uppercased()) && (a["host"] == nil || a["host"]?.lowercased() == mock.metaData.url.host?.lowercased()) && (a["path"] == nil || mock.metaData.url.path.contains(a["path"]!)) && (a["scenario"] == nil || a["scenario"] == mock.metaData.scenario)
            }
            return try CLIOutput.object(mocks)
        case "show": return try CLIOutput.object(c.workspace.mock(id: c.id(), domain: domain))
        case "apply", "create", "import":
            let models: [MockModel]
            let data = try c.args.input()
            let format = c.args.options["format"] ?? (String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("curl ") ? "curl" : "json")
            if format == "curl" {
                let request = try CurlRequestParser.parse(String(decoding: data, as: UTF8.self))
                let mock = MockModel(metaData: .init(url: request.url, method: request.method, appendTime: Date(), updateTime: Date(), httpStatus: 200, responseTime: 0, scenario: ""), requestHeader: .init(request.headers), responseHeader: "{}", requestBody: request.body.map { String(decoding: $0, as: UTF8.self) } ?? "", responseBody: "", matching: .init(endpoint: .init(method: request.method, host: request.url.host ?? "", path: .init(value: request.url.path))))
                if c.args.flags.contains("fetch") { models = [try await c.core.reload(mock: mock, domain: domain, root: c.workspace.root).current] } else { models = [mock] }
            } else if format == "json" { models = try MockBundle.decode(data) }
            else { throw WorkspaceFailure("invalid_format", "Format must be json or curl") }
            if action == "create" { guard models.count == 1, !(try c.workspace.mocks(domain: domain)).contains(where: { $0.id == models[0].id }) else { throw WorkspaceFailure("conflict", "create requires one new mock") } }
            try c.workspace.apply(models, domain: domain)
            return ["applied": models.map(\.id)]
        case "update":
            let mock = try c.workspace.mock(id: c.id(), domain: domain)
            let previous = try CLIOutput.object(mock) as! [String: Any]
            guard let patch = try JSONSerialization.jsonObject(with: c.args.input()) as? [String: Any] else { throw WorkspaceFailure("invalid_input", "Update requires a JSON object") }
            var normalized = patch
            var metadata = patch["metaData"] as? [String: Any] ?? [:]
            for key in ["url", "method", "scenario", "id"] { if let value = normalized.removeValue(forKey: key) { metadata[key] = value } }
            if let response = normalized.removeValue(forKey: "response") as? [String: Any] {
                for (key, value) in response { switch key { case "body": normalized["responseBody"] = value; case "headers": normalized["responseHeader"] = value; case "status": metadata["httpStatus"] = value; case "delay": metadata["responseTime"] = value; default: throw WorkspaceFailure("invalid_input", "Unknown response field \(key)") } }
            }
            if let value = normalized.removeValue(forKey: "headers") { normalized["requestHeader"] = value }
            if let value = normalized.removeValue(forKey: "body") { normalized["requestBody"] = value }
            metadata["updateTime"] = try CLIOutput.object(Date()); normalized["metaData"] = metadata
            let updated = try JSONDecoder.shared.decode(MockModel.self, from: JSONSerialization.data(withJSONObject: merge(previous, normalized)))
            guard updated.id == mock.id else { throw WorkspaceFailure("invalid_input", "Update cannot change ID; use copy") }
            try c.workspace.apply([updated], domain: domain); return try CLIOutput.object(updated)
        case "matching", "enable", "disable":
            let mock = try c.workspace.mock(id: c.id(), domain: domain)
            if action == "matching" {
                let data = try c.args.input()
                mock.matching = try JSONDecoder().decode(MockMatching?.self, from: data)
            } else {
                if mock.matching == nil { mock.matching = .init(endpoint: .init(method: mock.metaData.method, host: mock.metaData.url.host ?? "", path: .init(value: mock.metaData.url.path))) }
                mock.matching?.enabled = action == "enable"
            }
            mock.metaData.updateTime = Date(); try c.workspace.apply([mock], domain: domain); return try CLIOutput.object(mock)
        case "delete": let id = try c.id(); try c.workspace.delete(ids: [id], domain: domain); return ["deleted": id]
        case "copy", "move":
            let destination = try c.args.require("to-domain"); try c.workspace.checkDomain(destination)
            guard destination != domain || action == "copy" else { throw WorkspaceFailure("invalid_arguments", "Source and destination domain are the same") }
            let mock = try c.workspace.mock(id: c.id(), domain: domain).copy() as! MockModel
            if action == "copy" { mock.metaData.id = UUID().uuidString }
            if action == "move", (try c.workspace.mocks(domain: destination)).contains(where: { $0.id == mock.id }) { throw WorkspaceFailure("conflict", "Destination contains this ID") }
            try c.workspace.apply([mock], domain: destination)
            if action == "move" {
                do { try c.workspace.delete(ids: [mock.id], domain: domain) }
                catch { try? c.workspace.delete(ids: [mock.id], domain: destination); throw error }
            }
            return ["id": mock.id, "domain": destination]
        case "export":
            let models = c.args.words.count > 2 || c.args.options["id"] != nil ? [try c.workspace.mock(id: c.id(), domain: domain)] : try c.workspace.mocks(domain: domain)
            let format = c.args.options["format"] ?? "json"
            let value: Any
            if format == "json" { value = ["mocks": try CLIOutput.object(models)] }
            else if format == "curl" { value = try models.map { CurlRequestParser.export(.init(url: $0.metaData.url, method: $0.metaData.method, headers: try $0.requestHeader.asDictionary(), body: $0.requestBody.isEmpty ? nil : Data($0.requestBody.utf8))) } }
            else { throw WorkspaceFailure("invalid_format", "Format must be json or curl") }
            if let path = c.args.options["output"] {
                let bytes = format == "curl" ? Data((value as! [String]).joined(separator: "\n").utf8) : try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
                try bytes.write(to: URL(fileURLWithPath: path), options: .atomic); return ["output": URL(fileURLWithPath: path).path]
            }; return value
        case "reload":
            let mock = try c.workspace.mock(id: c.id(), domain: domain)
            let result = try await c.core.reload(mock: mock, domain: domain, root: c.workspace.root)
            if c.args.flags.contains("save") { try c.workspace.apply([result.current], domain: domain) }
            return ["saved": c.args.flags.contains("save"), "diff": try CLIOutput.object(result)]
        default: throw unknown(c.args)
        }
    }
    static func merge(_ original: [String: Any], _ patch: [String: Any]) -> [String: Any] {
        var result = original
        for (key, value) in patch {
            if ["requestBody", "responseBody", "requestHeader", "responseHeader", "conditions"].contains(key) { result[key] = value }
            else if let child = value as? [String: Any], let old = result[key] as? [String: Any] { result[key] = merge(old, child) }
            else { result[key] = value }
        }; return result
    }
}
