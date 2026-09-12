import Foundation

enum ModifierClaudeResponseParserError: LocalizedError, Equatable {
    case noTransformerFound

    var errorDescription: String? {
        switch self {
        case .noTransformerFound:
            return "Claude reply did not contain a transformer(req, chain) function"
        }
    }
}

enum ModifierClaudeResponseParser {
    /// Extracts the first `function transformer(...)` implementation from assistant text.
    static func extractTransformerJavaScript(from text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ModifierClaudeResponseParserError.noTransformerFound
        }

        if let fenced = extractFromFence(trimmed) {
            return fenced
        }
        if let bare = extractBareFunction(trimmed) {
            return bare
        }
        throw ModifierClaudeResponseParserError.noTransformerFound
    }

    private static func extractFromFence(_ text: String) -> String? {
        let patterns = [
            #"```(?:javascript|js)\s*\n([\s\S]*?)```"#,
            #"```\s*\n([\s\S]*?)```"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range),
                  match.numberOfRanges > 1,
                  let contentRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            let content = String(text[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if content.contains("function transformer") {
                return content
            }
        }
        return nil
    }

    private static func extractBareFunction(_ text: String) -> String? {
        guard let start = text.range(of: "function transformer") else { return nil }
        let fromStart = text[start.lowerBound...]
        // Prefer a complete-looking function body; fall back to the remainder.
        if let closing = balancedFunctionEnd(in: String(fromStart)) {
            return closing.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let candidate = String(fromStart).trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? nil : candidate
    }

    private static func balancedFunctionEnd(in text: String) -> String? {
        guard let braceStart = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = braceStart
        while index < text.endIndex {
            let ch = text[index]
            if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[text.startIndex...index])
                }
            }
            index = text.index(after: index)
        }
        return nil
    }
}
