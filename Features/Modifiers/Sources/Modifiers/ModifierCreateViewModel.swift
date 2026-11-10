import CommonKit
import CommonViewsKit
import Foundation
import SwiftUI

@Observable
@MainActor
public final class MockModifierCreateViewModel {
    public struct Result: Equatable {
        public let id: String
        public let seed: MockModifierCreationSeed
    }

    private var seed: MockModifierCreationSeed
    private let apiClient: MockModifierAPIClientInterface
    private let notificationManager: NotificationManagerInterface

    var modifierId = ""
    var path: String
    var method: String
    var scenario: String
    var order = 1
    var sampleMockRequestId: String
    var isCreating = false
    var fieldError: String?
    var isImportingCurl = false
    var curlCommand = ""
    var curlError: String?
    var importedCurl = false

    public init(
        seed: MockModifierCreationSeed,
        apiClient: MockModifierAPIClientInterface = MockModifierAPIClient(),
        notificationManager: NotificationManagerInterface = NotificationManager.shared
    ) {
        self.seed = seed
        self.apiClient = apiClient
        self.notificationManager = notificationManager
        path = seed.path
        method = seed.method
        scenario = seed.scenario
        sampleMockRequestId = seed.mockId ?? ""
    }

    func create(domain: String) async -> Result? {
        let id = modifierId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !path.isEmpty, !method.isEmpty, order >= 1 else {
            fieldError = "ID, path, method and a positive order are required"
            return nil
        }
        var request = MockModifierWriteRequest(
            id: id,
            path: path,
            method: method.uppercased(),
            scenario: scenario.isEmpty ? nil : scenario,
            order: order,
            sampleMockRequestId: sampleMockRequestId.isEmpty ? nil : sampleMockRequestId,
            transformerCode: """
            function transformer(req, chain) {
              var res = chain.proceed(req);

              return res;
            }
            """
        )
        isCreating = true
        defer { isCreating = false }
        do {
            let previewSeed = makePreviewSeed()
            if !previewSeed.url.isEmpty {
                guard let url = URL(string: previewSeed.url),
                      let headersData = previewSeed.requestHeadersJSON.data(using: .utf8) else {
                    throw MockModifierAPIError.badRequest
                }
                var previewRequest = URLRequest(url: url)
                previewRequest.httpMethod = previewSeed.method.uppercased()
                previewRequest.allHTTPHeaderFields = try JSONDecoder().decode([String: String].self, from: headersData)
                previewRequest.httpBody = Data(previewSeed.requestBody.utf8)
                request.previewCurl = previewRequest.cURL(pretty: true)
                request.previewSource = previewSeed.mockId == nil ? .live : .mock
                request.previewScenario = previewSeed.scenario
            }
            try await apiClient.createModifier(domain: domain, request: request)
            notificationManager.show(title: "Modifier created", color: .green)
            return Result(id: id, seed: makePreviewSeed())
        } catch {
            fieldError = error.localizedDescription
            return nil
        }
    }

    func importCurl() {
        do {
            let request = try CurlParser(curlCommand).buildRequest()
            guard let url = request.url else { return }
            let importedPath = url.path.isEmpty ? "/" : url.path
            let importedMethod = request.httpMethod ?? "GET"
            let headers = try JSONEncoder().encode(request.allHTTPHeaderFields ?? [:])
            if path != importedPath || method.uppercased() != importedMethod { sampleMockRequestId = "" }
            path = importedPath
            method = importedMethod
            scenario = request.value(forHTTPHeaderField: "X-Merlin-Scenario") ?? request.value(forHTTPHeaderField: "scenario") ?? scenario
            if modifierId.isEmpty {
                modifierId = importedPath.replacingOccurrences(of: #"[^a-zA-Z0-9_-]+"#, with: "-", options: .regularExpression)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                if modifierId.isEmpty { modifierId = "modifier" }
            }
            seed = .init(
                url: url.absoluteString, path: importedPath, method: importedMethod, scenario: scenario,
                requestHeadersJSON: String(decoding: headers, as: UTF8.self),
                requestBody: request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
            )
            importedCurl = true
            curlError = nil
            fieldError = nil
            isImportingCurl = false
        } catch {
            curlError = error.localizedDescription
        }
    }

    /// Keeps mock URL/headers/body from the creation seed and syncs form metadata.
    private func makePreviewSeed() -> MockModifierCreationSeed {
        return MockModifierCreationSeed(
            mockId: sampleMockRequestId.isEmpty ? nil : sampleMockRequestId,
            url: seed.url,
            path: path,
            method: method,
            scenario: scenario,
            requestHeadersJSON: seed.requestHeadersJSON,
            requestBody: seed.requestBody
        )
    }
}
