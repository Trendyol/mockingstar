import CommonKit
import Foundation
import JavaScriptCore

enum ModifierParseError: Error, Equatable {
    case invalidJSContext
    case missingRequiredField(String)
    case syntaxError(String)
    case invalidModifierId(String)
}

final class ModifierParser {
    private let logger = Logger(category: "ModifierParser")

    /// Parses modifier metadata from JavaScript, deriving `id` from `filenameId`.
    ///
    /// Legacy files may still contain `var id`, `var enabled`, and `var priority`. Those values are
    /// ignored for identity/activation (`id` comes from the filename; `enabled` defaults to false
    /// here). `priority` is mapped to `order` when `order` is absent.
    func parse(jsCode: String, filenameId: String) throws -> ModifierModel {
        try Self.validateModifierId(filenameId)

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

        let orderValue: Int
        if let order = read("order"), !order.isUndefined, !order.isNull {
            orderValue = max(1, Int(order.toInt32()))
        } else if let priority = read("priority"), !priority.isUndefined, !priority.isNull {
            orderValue = max(1, Int(priority.toInt32()))
        } else {
            orderValue = 1
        }

        return ModifierModel(
            id: filenameId,
            path: path,
            method: method.uppercased(),
            scenario: optionalString("scenario"),
            enabled: false,
            order: orderValue,
            sampleMockRequestId: optionalString("sampleMockRequestId"),
            transformerCode: Self.extractTransformerBody(from: jsCode)
        )
    }

    /// Serializes a canonical on-disk representation without `id`, `enabled`, or legacy `priority`.
    func serialize(_ model: ModifierModel) -> String {
        let transformerBody = Self.extractTransformerBody(from: model.transformerCode)
        return """
        // metadata
        var path = \(escape(model.path))
        var method = \(escape(model.method))
        var scenario = \(model.scenario.map(escape) ?? "null")
        var order = \(max(1, model.order))
        var sampleMockRequestId = \(model.sampleMockRequestId.map(escape) ?? "null")

        \(transformerBody)
        """
    }

    static func extractTransformerBody(from code: String) -> String {
        if let range = code.range(of: "function transformer") {
            return String(code[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func validateModifierId(_ id: String) throws {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed == id,
              !id.contains("/"),
              !id.contains("\\"),
              !id.contains(".."),
              !id.contains("\0"),
              id != "." ,
              id != ".." else {
            throw ModifierParseError.invalidModifierId(id)
        }
    }

    private func escape(_ str: String) -> String {
        "\"\(str.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
