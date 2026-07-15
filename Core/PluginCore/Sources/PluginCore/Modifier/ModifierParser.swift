import CommonKit
import Foundation
import JavaScriptCore

enum ModifierParseError: Error, Equatable {
    case invalidJSContext
    case missingRequiredField(String)
    case syntaxError(String)
}

final class ModifierParser {
    private let logger = Logger(category: "ModifierParser")

    func parse(jsCode: String) throws -> ModifierModel {
        guard let context = JSContext() else { throw ModifierParseError.invalidJSContext }

        var syntaxErrorMessage: String?
        context.exceptionHandler = { _, exception in
            syntaxErrorMessage = exception?.toString()
        }

        context.evaluateScript(jsCode)
        if let syntaxErrorMessage {
            logger.error("Modifier parse syntax error: \(syntaxErrorMessage)")
            throw ModifierParseError.syntaxError(syntaxErrorMessage)
        }

        func read(_ key: String) -> JSValue? {
            let value = context.objectForKeyedSubscript(key)
            return value?.isUndefined == false ? value : nil
        }

        guard let id = read("id")?.toString(), !id.isEmpty else {
            throw ModifierParseError.missingRequiredField("id")
        }

        guard let path = read("path")?.toString(), !path.isEmpty else {
            throw ModifierParseError.missingRequiredField("path")
        }

        guard let method = read("method")?.toString(), !method.isEmpty else {
            throw ModifierParseError.missingRequiredField("method")
        }

        func optionalString(_ key: String) -> String? {
            guard let raw = read(key)?.toString(), !raw.isEmpty, raw != "null" else { return nil }
            return raw
        }

        return ModifierModel(
            id: id,
            path: path,
            method: method.uppercased(),
            scenario: optionalString("scenario"),
            enabled: read("enabled")?.toBool() ?? false,
            priority: Int(read("priority")?.toInt32() ?? 0),
            sampleMockRequestId: optionalString("sampleMockRequestId"),
            transformerCode: jsCode
        )
    }

    func serialize(_ model: ModifierModel, transformerBody: String) -> String {
        """
        // metadata
        var id = \(escape(model.id))
        var path = \(escape(model.path))
        var method = \(escape(model.method))
        var scenario = \(model.scenario.map(escape) ?? "null")
        var enabled = \(model.enabled)
        var priority = \(model.priority)
        var sampleMockRequestId = \(model.sampleMockRequestId.map(escape) ?? "null")

        \(transformerBody)
        """
    }

    private func escape(_ str: String) -> String {
        "\"\(str.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
