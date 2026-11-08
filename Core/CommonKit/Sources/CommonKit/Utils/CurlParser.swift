//
//  CurlParser.swift
//  CommonKit
//
//  Created by Yusuf Özgül on 28.03.2025.
//

import Foundation
import ArgumentParser
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct CurlParser {
    private let curlCommand: String

    public init(_ curlCommand: String) {
        self.curlCommand = curlCommand
    }

    public func buildRequest() throws -> URLRequest {
        let arguments = try parseCommandToArguments()
        let parsedCommand = try CURLCommand.parse(arguments)

        guard parsedCommand.urlArgument.allSatisfy({ !$0.hasPrefix("-") }),
              parsedCommand.urlArgument.count + (parsedCommand.urlOption == nil ? 0 : 1) == 1,
              !parsedCommand.url.isEmpty,
              let url = URL(string: parsedCommand.url, encodingInvalidCharacters: false),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            throw CURLError.invalidURL
        }

        var request = URLRequest(url: url)
        if let method = parsedCommand.request {
            request.httpMethod = method.uppercased()
        } else if parsedCommand.head {
            request.httpMethod = "HEAD"
        } else if parsedCommand.get {
            request.httpMethod = "GET"
        } else {
            request.httpMethod = parsedCommand.bodies.isEmpty ? "GET" : "POST"
        }
        guard request.httpMethod?.range(of: #"^[A-Z!#$%&'*+.^_`|~0-9-]+$"#, options: .regularExpression) != nil else {
            throw CURLError.parsingFailed
        }
        var suppressed = Set<String>()
        for header in parsedCommand.headers {
            guard !header.contains("\n"), !header.contains("\r") else { throw CURLError.parsingFailed }
            if let separator = header.firstIndex(of: ":"), separator != header.startIndex {
                let name = String(header[..<separator]).trimmingCharacters(in: .whitespaces)
                let value = String(header[header.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
                request.setValue(value.isEmpty ? nil : value, forHTTPHeaderField: name)
                if value.isEmpty { suppressed.insert(name.lowercased()) }
                else { suppressed.remove(name.lowercased()) }
            } else if header.hasSuffix(";"), header.count > 1 {
                request.setValue("", forHTTPHeaderField: String(header.dropLast()))
            } else {
                throw CURLError.parsingFailed
            }
        }
        if let user = parsedCommand.user {
            guard user.contains(":") else { throw CURLError.parsingFailed }
            request.setValue("Basic " + Data(user.utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
        }
        if let cookie = parsedCommand.cookie {
            guard cookie.contains("=") else { throw CURLError.parsingFailed }
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        if let agent = parsedCommand.userAgent { request.setValue(agent, forHTTPHeaderField: "User-Agent") }
        if let referer = parsedCommand.referer { request.setValue(referer, forHTTPHeaderField: "Referer") }
        if !parsedCommand.json.isEmpty {
            if request.value(forHTTPHeaderField: "Content-Type") == nil, !suppressed.contains("content-type") {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            if request.value(forHTTPHeaderField: "Accept") == nil, !suppressed.contains("accept") {
                request.setValue("application/json", forHTTPHeaderField: "Accept")
            }
        }
        guard !parsedCommand.fileBodies.contains(where: { $0.hasPrefix("@") }) else {
            throw CURLError.fileInputUnsupported
        }
        if !parsedCommand.bodies.isEmpty {
            let body = parsedCommand.bodies.joined(separator: "&")
            if parsedCommand.get {
                guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw CURLError.invalidURL }
                let query = [components.percentEncodedQuery, body].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "&")
                guard URLComponents(string: "?" + query)?.percentEncodedQuery == query else { throw CURLError.invalidURL }
                components.percentEncodedQuery = query
                request.url = components.url
            } else {
                request.httpBody = Data(body.utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil, !suppressed.contains("content-type") {
                    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                }
            }
        }
        return request
    }

    private func parseCommandToArguments() throws -> [String] {
        let chars = Array(curlCommand)
        var arguments: [String] = []
        var word = ""
        var started = false
        var quote: Character?
        var ansi = false
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if char == "\\", quote != "'" || ansi {
                index += 1
                guard index < chars.count else { throw CURLError.parsingFailed }
                let next = chars[index]
                if ansi {
                    let escapes: [Character: String] = ["n": "\n", "r": "\r", "t": "\t", "\\": "\\", "'": "'"]
                    guard let escaped = escapes[next] else { throw CURLError.parsingFailed }
                    word += escaped
                } else if next == "\n" || next == "\r\n" {
                    index += 1
                    continue
                } else {
                    if quote == "\"", !["\"", "\\", "$", "`"].contains(next) { word.append("\\") }
                    word.append(next)
                }
                started = true
            } else if let currentQuote = quote {
                if char == currentQuote { quote = nil; ansi = false }
                else {
                    if currentQuote == "\"", char == "$" || char == "`" { throw CURLError.parsingFailed }
                    word.append(char)
                }
            } else if char == "$", index + 1 < chars.count, chars[index + 1] == "'" {
                quote = "'"; ansi = true; started = true; index += 1
            } else if char == "'" || char == "\"" {
                quote = char; started = true
            } else if char.isWhitespace {
                if started { arguments.append(word) }
                word = ""; started = false
            } else {
                if ";|&<>`$".contains(char) { throw CURLError.parsingFailed }
                word.append(char); started = true
            }
            index += 1
        }
        guard quote == nil else { throw CURLError.parsingFailed }
        if started { arguments.append(word) }
        guard let command = arguments.first,
              ["curl", "curl.exe"].contains(command.components(separatedBy: "/").last ?? "") else { throw CURLError.parsingFailed }
        return Array(arguments.dropFirst())
    }
}

struct CURLCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "curl",
        abstract: "Transfer data from or to a server"
    )

    @Option(name: [.customLong("url")], help: "URL to work with")
    var urlOption: String?

    @Flag(name: [.customShort("L"), .customLong("location")]) var location = false
    @Flag(name: [.customShort("I"), .customLong("head")]) var head = false
    @Flag(name: [.customShort("G"), .customLong("get")]) var get = false
    @Flag(name: [.customLong("compressed")]) var compressed = false
    @Flag(name: [.customShort("k"), .customLong("insecure")]) var insecure = false
    @Flag(name: [.customShort("s"), .customLong("silent")]) var silent = false
    @Flag(name: [.customShort("S"), .customLong("show-error")]) var showError = false
    @Flag(name: [.customShort("f"), .customLong("fail")]) var fail = false
    @Flag(name: [.customLong("fail-with-body")]) var failWithBody = false
    @Flag(name: [.customShort("g"), .customLong("globoff")]) var globoff = false
    @Flag(name: [.customLong("http1.1")]) var http1 = false
    @Flag(name: [.customLong("http2")]) var http2 = false

    @Option(name: [.customShort("X"), .customLong("request")], help: "The HTTP method to use")
    var request: String?

    @Option(name: [.customShort("H"), .customLong("header")], help: "Pass custom header(s) to server")
    var headers: [String] = []

    @Option(name: [.customShort("d"), .customLong("data")], help: "HTTP POST data")
    var data: [String] = []

    @Option(name: [.customLong("data-raw")], help: "HTTP POST data, '@' allowed")
    var dataRaw: [String] = []

    @Option(name: [.customLong("data-binary")]) var dataBinary: [String] = []
    @Option(name: [.customLong("data-ascii")]) var dataASCII: [String] = []
    @Option(name: [.customLong("json")]) var json: [String] = []
    @Option(name: [.customShort("u"), .customLong("user")]) var user: String?
    @Option(name: [.customShort("b"), .customLong("cookie")]) var cookie: String?
    @Option(name: [.customShort("A"), .customLong("user-agent")]) var userAgent: String?
    @Option(name: [.customShort("e"), .customLong("referer")]) var referer: String?

    var fileBodies: [String] { data + dataBinary + dataASCII + json }
    var bodies: [String] { data + dataRaw + dataBinary + dataASCII + json }

    @Argument(parsing: .allUnrecognized, help: "The URL to request")
    var urlArgument: [String] = []

    var url: String {
        if let urlOption = urlOption {
            return urlOption
        }

        if let firstUrl = urlArgument.first(where: { $0.hasPrefix("http://") || $0.hasPrefix("https://") }) {
            return firstUrl
        }

        return urlArgument.first ?? ""
    }
}

enum CURLError: Error, LocalizedError, Equatable {
    case invalidURL
    case parsingFailed
    case missingURL
    case fileInputUnsupported

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Valid URL not found. Make sure the URL starts with http:// or https://."
        case .parsingFailed:
            return "Failed to parse cURL command. Please check the command syntax."
        case .missingURL:
            return "URL not specified. Add '--url' parameter or directly provide the URL."
        case .fileInputUnsupported:
            return "File-based cURL inputs are not supported. Paste the request body directly."
        }
    }

    var failureReason: String? {
        switch self {
        case .invalidURL:
            return "URL format is invalid or missing."
        case .parsingFailed:
            return "There might be an error in the command syntax."
        case .missingURL:
            return "A curl command requires a URL."
        case .fileInputUnsupported:
            return "The request body references a local file."
        }
    }
}
