import Foundation

enum ModifierJSONPathComponent: Equatable {
    case key(String)
    case index(Int)
}

enum ModifierJSONPath {
    struct Resolved: Equatable {
        let path: [ModifierJSONPathComponent]
        let literal: String
    }

    static func resolve(json: String, utf16Offset offset: Int) -> Resolved? {
        let scanner = Scanner(text: json)
        scanner.scanValue(path: [])
        guard !scanner.entries.isEmpty else { return nil }

        let containing = scanner.entries.filter { $0.range.contains(offset) || $0.range.upperBound == offset }
        let best = containing.min { lhs, rhs in
            (lhs.range.upperBound - lhs.range.lowerBound) < (rhs.range.upperBound - rhs.range.lowerBound)
        }
        guard let best else { return nil }
        return Resolved(path: best.path, literal: best.literal)
    }

    private struct Entry {
        let path: [ModifierJSONPathComponent]
        let range: Range<Int>
        let literal: String
    }

    private final class Scanner {
        private let ns: NSString
        private var pos: Int = 0
        var entries: [Entry] = []

        init(text: String) {
            ns = text as NSString
        }

        private var isAtEnd: Bool { pos >= ns.length }

        private func peek() -> unichar? {
            guard pos < ns.length else { return nil }
            return ns.character(at: pos)
        }

        private func skipWhitespace() {
            while let c = peek(), c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D {
                pos += 1
            }
        }

        func scanValue(path: [ModifierJSONPathComponent]) {
            skipWhitespace()
            guard let c = peek() else { return }
            let start = pos
            switch c {
            case 0x7B: // {
                scanObject(path: path)
            case 0x5B: // [
                scanArray(path: path)
            case 0x22: // "
                scanString()
            default:
                scanPrimitive()
            }
            let range = start..<pos
            let literal = ns.substring(with: NSRange(location: start, length: pos - start))
            entries.append(Entry(path: path, range: range, literal: literal))
        }

        private func scanObject(path: [ModifierJSONPathComponent]) {
            pos += 1 // {
            skipWhitespace()
            if peek() == 0x7D { pos += 1; return }
            while !isAtEnd {
                skipWhitespace()
                guard peek() == 0x22 else { break }
                let keyStart = pos
                let key = readStringLiteral()
                let keyRange = keyStart..<pos
                skipWhitespace()
                if peek() == 0x3A { pos += 1 } // :
                let childPath = path + [.key(key)]
                scanValue(path: childPath)
                if let last = entries.last, last.path == childPath {
                    entries.append(Entry(path: childPath, range: keyRange, literal: last.literal))
                }
                skipWhitespace()
                if peek() == 0x2C { pos += 1; continue } // ,
                if peek() == 0x7D { pos += 1; break } // }
                break
            }
        }

        private func scanArray(path: [ModifierJSONPathComponent]) {
            pos += 1 // [
            skipWhitespace()
            if peek() == 0x5D { pos += 1; return }
            var index = 0
            while !isAtEnd {
                scanValue(path: path + [.index(index)])
                index += 1
                skipWhitespace()
                if peek() == 0x2C { pos += 1; continue } // ,
                if peek() == 0x5D { pos += 1; break } // ]
                break
            }
        }

        private func scanString() {
            _ = readStringLiteral()
        }

        @discardableResult
        private func readStringLiteral() -> String {
            let start = pos
            pos += 1
            while pos < ns.length {
                let c = ns.character(at: pos)
                if c == 0x5C {
                    pos += 2
                    continue
                }
                pos += 1
                if c == 0x22 { break }
            }
            let raw = ns.substring(with: NSRange(location: start, length: pos - start))
            if let data = raw.data(using: .utf8),
               let decoded = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? String {
                return decoded
            }
            return raw
        }

        private func scanPrimitive() {
            while pos < ns.length {
                let c = ns.character(at: pos)
                if c == 0x2C || c == 0x7D || c == 0x5D || c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D {
                    break
                }
                pos += 1
            }
        }
    }
}

enum ModifierTransformerEditor {
    struct Result: Equatable {
        let code: String
        let focusLine: Int?
    }

    static func lhs(for path: [ModifierJSONPathComponent]) -> String {
        var result = "res.body"
        for component in path {
            switch component {
            case .key(let key):
                result += isIdentifier(key) ? ".\(key)" : "[\(stringLiteral(key))]"
            case .index(let index):
                result += "[\(index)]"
            }
        }
        return result
    }

    static func applyAssignment(
        path: [ModifierJSONPathComponent],
        valueLiteral: String,
        to code: String
    ) -> Result {
        let target = lhs(for: path)
        var working = ensureProceed(in: code)
        working = rewriteProceedReturnToRes(in: working)

        if let existing = assignmentLineRange(of: target, in: working) {
            let indent = leadingWhitespace(of: String(working[existing]))
            let line = "\(indent)\(target) = \(valueLiteral);"
            working.replaceSubrange(existing, with: line)
            return Result(code: working, focusLine: lineNumber(of: existing.lowerBound, in: working))
        }

        let assignment = "\(target) = \(valueLiteral);"
        if let insertAt = firstReturnIndex(in: working) {
            let indent = lineIndent(at: insertAt, in: working)
            let lineStart = startOfLine(containing: insertAt, in: working)
            let prefixOnLine = working[lineStart..<insertAt]
            let onlyIndent = prefixOnLine.allSatisfy { $0 == " " || $0 == "\t" }
            let insertion = onlyIndent
                ? "\(assignment)\n\(indent)"
                : "\n\(indent)\(assignment)\n\(indent)"
            working.insert(contentsOf: insertion, at: insertAt)
            return Result(code: working, focusLine: lineNumber(of: insertAt, in: working))
        }

        if let bodyEnd = transformerBodyRange(in: working)?.upperBound {
            let indent = insertionIndent(of: working)
            let prefix = working[working.index(before: bodyEnd)] == "\n" ? "" : "\n"
            working.insert(contentsOf: "\(prefix)\(indent)\(assignment)\n", at: bodyEnd)
            return Result(code: working, focusLine: lineNumber(of: bodyEnd, in: working))
        }

        working += "\n\(assignment)"
        return Result(code: working, focusLine: working.components(separatedBy: "\n").count)
    }

    static func ensureProceed(in code: String) -> String {
        if code.range(of: #"var\s+res\s*=\s*chain\.proceed"#, options: .regularExpression) != nil {
            return code
        }
        guard let body = transformerBodyRange(in: code) else { return code }
        var result = code
        result.insert(contentsOf: "\n  var res = chain.proceed(req);", at: body.lowerBound)
        return result
    }

    private static func rewriteProceedReturnToRes(in code: String) -> String {
        let pattern = #"return\s+chain\.proceed\s*\([^)]*\)[ \t]*;?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return code }
        let range = NSRange(code.startIndex..., in: code)
        return regex.stringByReplacingMatches(in: code, range: range, withTemplate: "return res;")
    }

    private static func assignmentLineRange(of target: String, in code: String) -> Range<String.Index>? {
        let escaped = NSRegularExpression.escapedPattern(for: target)
        let pattern = #"(?m)^[ \t]*"# + escaped + #"\s*=.*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(code.startIndex..., in: code)
        guard let match = regex.firstMatch(in: code, range: nsRange),
              let range = Range(match.range, in: code) else { return nil }
        return range
    }

    private static func firstReturnIndex(in code: String) -> String.Index? {
        let searchRange = transformerBodyRange(in: code) ?? code.startIndex..<code.endIndex
        let body = String(code[searchRange])
        guard let regex = try? NSRegularExpression(pattern: #"\breturn\b"#) else { return nil }
        let nsRange = NSRange(body.startIndex..., in: body)
        guard let match = regex.firstMatch(in: body, range: nsRange),
              let matchRange = Range(match.range, in: body) else { return nil }
        let offset = body.distance(from: body.startIndex, to: matchRange.lowerBound)
        return code.index(searchRange.lowerBound, offsetBy: offset)
    }

    private static func transformerBodyRange(in code: String) -> Range<String.Index>? {
        guard let header = code.range(of: #"function\s+transformer\s*\([^)]*\)\s*\{"#, options: .regularExpression) else {
            return nil
        }
        var depth = 0
        var index = header.lowerBound
        var started = false
        while index < code.endIndex {
            let character = code[index]
            if character == "{" {
                depth += 1
                started = true
            } else if character == "}" {
                depth -= 1
                if started && depth == 0 {
                    return header.upperBound..<index
                }
            }
            index = code.index(after: index)
        }
        return nil
    }

    private static func startOfLine(containing index: String.Index, in code: String) -> String.Index {
        var start = index
        while start > code.startIndex {
            let previous = code.index(before: start)
            if code[previous] == "\n" { break }
            start = previous
        }
        return start
    }

    private static func lineIndent(at index: String.Index, in code: String) -> String {
        let start = startOfLine(containing: index, in: code)
        return String(code[start..<index].prefix { $0 == " " || $0 == "\t" })
    }

    private static func leadingWhitespace(of line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }

    private static func insertionIndent(of code: String) -> String {
        if let returnAt = firstReturnIndex(in: code) {
            return lineIndent(at: returnAt, in: code)
        }
        return "  "
    }

    private static func lineNumber(of index: String.Index, in code: String) -> Int {
        code[...index].filter { $0 == "\n" }.count + 1
    }

    static func isIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let pattern = "^[A-Za-z_$][A-Za-z0-9_$]*$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func stringLiteral(_ value: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
           let json = String(data: data, encoding: .utf8) {
            return String(json.dropFirst().dropLast())
        }
        return "\"\(value)\""
    }
}
