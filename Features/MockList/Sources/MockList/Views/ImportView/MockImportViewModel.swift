//
//  MockImportViewModel.swift
//  MockList
//
//  Created by Yusuf Özgül on 7.03.2025.
//

import CommonKit
import CommonViewsKit
import MockingStarCore
import SwiftUI

@Observable
final class MockImportViewModel {
    private let logger = Logger(category: "MockImportViewModel")
    var mockImportStyle: MockImportStyle = .cURL
    var importInput: String = ""
    var importFailedMessage: String = ""
    var shouldShowImportDone: Bool = false

    func importMock(for mockDomain: String) {
        importFailedMessage = ""
        Task {
            do {
                switch mockImportStyle {
                case .cURL:
                    try await curlImport(mockDomain: mockDomain)
                }
            } catch {
                logger.error("Import failed: \(error)")
                importFailedMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    private func curlImport(mockDomain: String) async throws {
        var url = ""
        var headers: [String: String] = [:]
        var method = "GET"

        // Normalize curl command
        let normalizedCurl = importInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\", with: "")

        // Parse headers using regex
        let headerPattern = "-H ['\"](.*?)['\"]"
        if let regex = try? NSRegularExpression(pattern: headerPattern, options: []) {
            let range = NSRange(normalizedCurl.startIndex..., in: normalizedCurl)
            let matches = regex.matches(in: normalizedCurl, options: [], range: range)

            for match in matches {
                if let range = Range(match.range(at: 1), in: normalizedCurl) {
                    let headerString = String(normalizedCurl[range])
                    let headerParts = headerString.split(separator: ":", maxSplits: 1).map(String.init)
                    if headerParts.count == 2 {
                        let key = headerParts[0].trimmingCharacters(in: .whitespaces)
                        let value = headerParts[1].trimmingCharacters(in: .whitespaces)
                        headers[key] = value
                    }
                }
            }
        }

        // Parse method using regex
        let methodPattern = "-X ['\"](GET|POST|PUT|DELETE)['\"]"
        if let regex = try? NSRegularExpression(pattern: methodPattern, options: []),
           let match = regex.firstMatch(in: normalizedCurl, options: [], range: NSRange(normalizedCurl.startIndex..., in: normalizedCurl)),
           let range = Range(match.range(at: 1), in: normalizedCurl) {
            method = String(normalizedCurl[range])
        }

        // Parse URL using regex
        let urlPattern = "curl.*?['\"](http[^'\"]*)['\"]"
        if let regex = try? NSRegularExpression(pattern: urlPattern, options: []),
           let match = regex.firstMatch(in: normalizedCurl, options: [], range: NSRange(normalizedCurl.startIndex..., in: normalizedCurl)),
           let range = Range(match.range(at: 1), in: normalizedCurl) {
            url = String(normalizedCurl[range])
        }

        guard let url = URL(string: url) else { throw MockImportError.urlError }
        let mockingStarCore = MockingStarCore()

        let importResult = try await mockingStarCore.importMock(url: url, method: method, headers: headers, body: nil, flags: MockServerFlags(mockSource: .default,
                                                                                                                                              scenario: nil,
                                                                                                                                              shouldNotMock: false,
                                                                                                                                              domain: mockDomain,
                                                                                                                                              deviceId: ""))

        switch importResult {
        case .alreadyMocked: throw MockImportError.alreadyMocked
        case .domainIgnoredByConfigs: throw MockImportError.domainIgnoredByConfigs
        default: break
        }
        shouldShowImportDone = true
    }
}

enum MockImportError: LocalizedError {
    case urlError
    case alreadyMocked
    case domainIgnoredByConfigs

    public var errorDescription: String? {
        return switch self {
        case .urlError: "URL creation failed"
        case .alreadyMocked: "Already mocked"
        case .domainIgnoredByConfigs: "Domain ignored by configs"
        }
    }
}

enum MockImportStyle: String, CaseIterable {
    case cURL
}
