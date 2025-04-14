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
    private let mockingStarCore: MockingStarCoreInterface
    private let fileSaver: FileSaverActorInterface
    var mockImportStyle: MockImportStyle = .cURL
    var importInput: String = ""
    var importFailedMessage: String = ""
    var shouldShowImportDone: Bool = false
    var isLoading = false

    init(mockingStarCore: MockingStarCoreInterface = MockingStarCore(),
         fileSaver: FileSaverActorInterface = FileSaverActor.shared) {
        self.mockingStarCore = mockingStarCore
        self.fileSaver = fileSaver
    }

    func importMock(for mockDomain: String) async {
        isLoading = true
        defer { isLoading = false }
        importFailedMessage = ""
        do {
            switch mockImportStyle {
            case .cURL:
                try await curlImport(mockDomain: mockDomain)
            case .file:
                let mockModel = try JSONDecoder.shared.decode(MockModel.self, from: importInput.data(using: .utf8) ?? Data())
                mockModel.metaData.id = UUID().uuidString
                try await fileSaver.saveFile(mock: mockModel, mockDomain: mockDomain)
                shouldShowImportDone = true
            }
        } catch {
            logger.error("Import failed: \(error)")
            importFailedMessage = "Import failed: \(error.localizedDescription)\n\(error)"
        }
    }

    private func curlImport(mockDomain: String) async throws {
        let request = try CurlParser(importInput).buildRequest()

        guard let url = request.url else { throw MockImportError.urlError }

        let importResult = try await mockingStarCore.importMock(url: url,
                                                              method: request.httpMethod ?? "GET",
                                                              headers: request.allHTTPHeaderFields ?? [:],
                                                              body: request.httpBody,
                                                              flags: MockServerFlags(mockSource: .default,
                                                                                   scenario: nil,
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
    case file

    var title: String {
        switch self {
        case .cURL: "cURL"
        case .file: "File"
        }
    }

    var placeholder: String {
        switch self {
        case .cURL: "curl -X POST https://api.example.com/some-endpoint -H 'Content-Type: application/json''"
        case .file: "Mocking Star exported file content"
        }
    }
}
