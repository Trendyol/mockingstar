import Foundation

/// Collapses a JSON sample into a value-free structural schema to keep Claude prompts small.
enum ModifierResponseSchemaSummarizer {
    static let maxSchemaCharacters = 8_000

    static func summarize(_ sampleResponse: String) -> String {
        let trimmed = sampleResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "(empty)" }
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return "(non-JSON body, \(trimmed.count) characters — structure unknown)"
        }

        let schema = schemaValue(from: json)
        guard let encoded = try? JSONSerialization.data(
            withJSONObject: schema,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ),
              var text = String(data: encoded, encoding: .utf8) else {
            return "(unable to encode schema)"
        }

        if text.count > maxSchemaCharacters {
            text = String(text.prefix(maxSchemaCharacters)) + "\n…(schema truncated)"
        }
        return text
    }

    private static func schemaValue(from value: Any) -> Any {
        switch value {
        case is NSNull:
            return "null"
        case is Bool:
            // Bool is bridged as NSNumber on Apple platforms; check before number.
            return "boolean"
        case let number as NSNumber:
            // Distinguish bool-backed NSNumber from real numbers.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return "boolean"
            }
            return "number"
        case is String:
            return "string"
        case let array as [Any]:
            if array.isEmpty { return ["<item>"] as [Any] }
            let itemSchemas = array.prefix(5).map(schemaValue(from:))
            return [mergedSchema(itemSchemas)]
        case let dict as [String: Any]:
            var result: [String: Any] = [:]
            for (key, nested) in dict {
                result[key] = schemaValue(from: nested)
            }
            return result
        default:
            return "unknown"
        }
    }

    private static func mergedSchema(_ values: [Any]) -> Any {
        guard let first = values.first else { return "unknown" }
        if values.allSatisfy({ $0 is [String: Any] }) {
            var merged: [String: Any] = [:]
            for case let dict as [String: Any] in values {
                for (key, value) in dict {
                    if let existing = merged[key] {
                        merged[key] = mergeLeaf(existing, value)
                    } else {
                        merged[key] = value
                    }
                }
            }
            return merged
        }
        if values.allSatisfy({ typeLabel($0) == typeLabel(first) }) {
            return first
        }
        let labels = Array(Set(values.map(typeLabel))).sorted()
        return labels.joined(separator: "|")
    }

    private static func mergeLeaf(_ lhs: Any, _ rhs: Any) -> Any {
        if let left = lhs as? [String: Any], let right = rhs as? [String: Any] {
            return mergedSchema([left, right])
        }
        if let left = lhs as? [Any], let right = rhs as? [Any] {
            let leftItem = left.first.map { [$0] } ?? []
            let rightItem = right.first.map { [$0] } ?? []
            return [mergedSchema(leftItem + rightItem)]
        }
        let leftLabel = typeLabel(lhs)
        let rightLabel = typeLabel(rhs)
        if leftLabel == rightLabel { return lhs }
        return [leftLabel, rightLabel].sorted().joined(separator: "|")
    }

    private static func typeLabel(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case is [String: Any]:
            return "object"
        case is [Any]:
            return "array"
        default:
            return "unknown"
        }
    }
}
