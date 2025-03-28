//
//  CurlParser.swift
//  MockList
//
//  Created by Yusuf Özgül on 28.03.2025.
//

import Foundation
import ArgumentParser

public struct CurlParser {
    private let curlCommand: String

    public init(_ curlCommand: String) {
        self.curlCommand = curlCommand
    }

    public func buildRequest() throws -> URLRequest {
        let arguments = try parseCommandToArguments()
        let parsedCommand = try CURLCommand.parse(arguments)

        guard !parsedCommand.url.isEmpty, let url = URL(string: parsedCommand.url, encodingInvalidCharacters: false) else {
            throw CURLError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = parsedCommand.request ?? "GET"
        if !parsedCommand.headers.isEmpty {
            var headerDict = [String: String]()
            for header in parsedCommand.headers {
                let components = header.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                if components.count == 2 {
                    headerDict[components[0]] = components[1]
                }
            }
            request.allHTTPHeaderFields = headerDict
        }

        if !parsedCommand.data.isEmpty {
            request.httpBody = parsedCommand.data.data(using: .utf8)
        } else if !parsedCommand.dataRaw.isEmpty {
            request.httpBody = parsedCommand.dataRaw.data(using: .utf8)
        }
        
        return request
    }

    private func parseCommandToArguments() throws -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: "[^\\s\"']+|\"([^\"]*)\"|'([^']*)'", options: [])
            let matches = regex.matches(in: curlCommand, options: [], range: NSRange(location: 0, length: curlCommand.utf16.count))

            var arguments: [String] = []

            for match in matches {
                if let range = Range(match.range, in: curlCommand) {
                    var argument = String(curlCommand[range])

                    if (argument.hasPrefix("\"") && argument.hasSuffix("\"")) ||
                       (argument.hasPrefix("'") && argument.hasSuffix("'")) {
                        argument = String(argument.dropFirst().dropLast())
                    }

                    if argument.lowercased() != "curl" {
                        arguments.append(argument)
                    }
                }
            }
            
            return arguments
        } catch {
            throw CURLError.parsingFailed
        }
    }
}

struct CURLCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "curl",
        abstract: "Transfer data from or to a server"
    )

    @Option(name: [.customLong("url")], help: "URL to work with")
    var urlOption: String?
    
    @Option(name: [.customShort("L"), .customLong("location")], help: "Follow redirects")
    var location: Bool = false

    @Option(name: [.customShort("X"), .customLong("request")], help: "The HTTP method to use")
    var request: String?

    @Option(name: [.customShort("H"), .customLong("header")], help: "Pass custom header(s) to server")
    var headers: [String] = []

    @Option(name: [.customShort("d"), .customLong("data")], help: "HTTP POST data")
    var data: String = ""
    
    @Option(name: [.customLong("data-raw")], help: "HTTP POST data, '@' allowed")
    var dataRaw: String = ""

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

enum CURLError: Error, LocalizedError {
    case invalidURL
    case parsingFailed
    case missingURL
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Valid URL not found. Make sure the URL starts with http:// or https://."
        case .parsingFailed:
            return "Failed to parse cURL command. Please check the command syntax."
        case .missingURL:
            return "URL not specified. Add '--url' parameter or directly provide the URL."
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
        }
    }
} 
