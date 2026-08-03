import CommonKit
import Foundation

class PluginJavaScriptBridge {
    let jsContext: PluginJavaScriptContext

    init() throws {
        let util = PluginsUtil()
        jsContext = try PluginJavaScriptContext(logHandler: util.log,
                                                 urlRequestHandler: { url, headers, method, body in
            util.urlRequest(url, headers, method, body)
        })
    }

    func loadFrom(jsCode: String, resetContext: Bool = false) throws {
        if resetContext {
            try jsContext.reset()
        }
        try jsContext.evaluate(jsCode)
    }

    func loadFrom(url: URL, resetContext: Bool = false) throws {
        try loadFrom(jsCode: String(contentsOf: url), resetContext: resetContext)
    }

    var config: [PluginConfiguration] {
        get throws {
            try jsContext.decode([PluginConfiguration].self, from: jsContext.getGlobalJSON(for: "config"))
        }
    }

    func setConfig(_ value: [PluginConfiguration]) throws {
        try jsContext.setGlobalJSON(jsContext.encode(value), for: "config")
    }

    func call<T: Decodable>(_ name: String, arguments: [Encodable]) throws -> T {
        let data = try jsContext.call(function: name, arguments: arguments.map { try jsContext.encode($0) })
        return try jsContext.decode(T.self, from: data)
    }

    func call<T: Decodable>(_ name: String, arguments: [Encodable]) async throws -> T {
        let data = try await jsContext.callAsync(function: name, arguments: arguments.map { try jsContext.encode($0) })
        return try jsContext.decode(T.self, from: data)
    }
}
