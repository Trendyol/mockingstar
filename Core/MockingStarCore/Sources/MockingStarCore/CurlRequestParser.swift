import Foundation
import CommonKit

/// Parses a cURL command as data. No shell, interpolation, subprocess or file reads.
public enum CurlRequestParser {
    public static func parse(_ command: String) throws -> MatchingRequest {
        let tokens = try tokenize(command)
        guard tokens.first == "curl" else { throw WorkspaceFailure("invalid_curl", "Input must begin with curl") }
        var url: String?, method: String?, headers: [String: String] = [:], bodies: [String] = []
        var i = 1, get = false
        func argument() throws -> String {
            i += 1
            guard i < tokens.count else { throw WorkspaceFailure("invalid_curl", "Missing cURL option value") }
            return tokens[i]
        }
        while i < tokens.count {
            let token = tokens[i]
            switch token {
            case "-X", "--request": method = try argument()
            case "-H", "--header":
                let header = try argument()
                guard let colon = header.firstIndex(of: ":") else { throw WorkspaceFailure("invalid_curl", "Header requires a colon") }
                headers[String(header[..<colon])] = String(header[header.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            case "-d", "--data", "--data-raw", "--data-binary", "--data-ascii", "--json":
                let body = try argument()
                guard !body.hasPrefix("@") || token == "--data-raw" else { throw WorkspaceFailure("unsupported_curl", "File-backed cURL data is unsupported; provide literal data") }
                bodies.append(body)
                if token == "--json" { headers["Content-Type"] = "application/json"; headers["Accept"] = "application/json" }
            case "--url": url = try argument()
            case "-G", "--get": get = true
            case "-I", "--head": method = "HEAD"
            case "-b", "--cookie": headers["Cookie"] = try argument()
            case "-A", "--user-agent": headers["User-Agent"] = try argument()
            case "-u", "--user": headers["Authorization"] = "Basic " + Data(try argument().utf8).base64EncodedString()
            case "--compressed", "-L", "--location", "-s", "--silent", "-S", "--show-error", "--globoff": break
            default:
                if token.hasPrefix("-") { throw WorkspaceFailure("unsupported_curl", "Unsupported cURL option: \(token)") }
                guard url == nil else { throw WorkspaceFailure("invalid_curl", "Exactly one URL is supported") }; url = token
            }
            i += 1
        }
        guard let raw = url, var parsed = URLComponents(string: raw), ["http", "https"].contains(parsed.scheme ?? ""), parsed.host != nil else { throw WorkspaceFailure("invalid_curl", "cURL requires an HTTP(S) URL") }
        if get && !bodies.isEmpty { parsed.percentEncodedQuery = [parsed.percentEncodedQuery, bodies.joined(separator: "&")].compactMap { $0 }.joined(separator: "&") }
        guard let target = parsed.url else { throw WorkspaceFailure("invalid_curl", "Invalid URL") }
        if !bodies.isEmpty && headers["Content-Type"] == nil { headers["Content-Type"] = "application/x-www-form-urlencoded" }
        return .init(url: target, method: method ?? (get || bodies.isEmpty ? "GET" : "POST"), headers: headers, body: get || bodies.isEmpty ? nil : Data(bodies.joined(separator: "&").utf8))
    }
    public static func export(_ request: MatchingRequest) -> String {
        func quote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        var parts = ["curl", "--request", quote(request.method), quote(request.url.absoluteString)]
        for (key, value) in request.headers.sorted(by: { $0.key < $1.key }) { parts += ["--header", quote(key + ": " + value)] }
        if let body = request.body { parts += ["--data-raw", quote(String(decoding: body, as: UTF8.self))] }
        return parts.joined(separator: " ")
    }
    private static func tokenize(_ input: String) throws -> [String] {
        var result: [String] = [], word = "", quote: Character?, escaped = false, started = false
        for char in input {
            if escaped { if char != "\n" { word.append(char); started = true }; escaped = false; continue }
            if char == "\\" && quote != "'" { escaped = true; continue }
            if let q = quote { if char == q { quote = nil } else { word.append(char) }; started = true; continue }
            if char == "'" || char == "\"" { quote = char; started = true }
            else if char.isWhitespace { if started { result.append(word); word = ""; started = false } }
            else if ";|<>`".contains(char) { throw WorkspaceFailure("invalid_curl", "Shell operators are unsupported") }
            else { word.append(char); started = true }
        }
        guard quote == nil, !escaped else { throw WorkspaceFailure("invalid_curl", "Unclosed quote or escape") }
        if started { result.append(word) }; return result
    }
}
