import CommonKit
import CommonViewsKit
import Foundation
import SwiftUI

@Observable
@MainActor
public final class ModifierCreateViewModel {
    public struct Result: Equatable {
        public let id: String
        public let seed: ModifierCreationSeed
    }

    private let seed: ModifierCreationSeed
    private let apiClient: ModifierAPIClientInterface
    private let notificationManager: NotificationManagerInterface

    var modifierId = ""
    var path: String
    var method: String
    var scenario: String
    var order = 1
    var sampleMockRequestId: String
    var isCreating = false
    var fieldError: String?

    public init(
        seed: ModifierCreationSeed,
        apiClient: ModifierAPIClientInterface = ModifierAPIClient(),
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
        let request = ModifierWriteRequest(
            id: id,
            path: path,
            method: method.uppercased(),
            scenario: scenario.isEmpty ? nil : scenario,
            order: order,
            sampleMockRequestId: sampleMockRequestId.isEmpty ? nil : sampleMockRequestId,
            transformerCode: """
            function transformer(req, chain) {
              return chain.proceed(req)
            }
            """
        )
        isCreating = true
        defer { isCreating = false }
        do {
            try await apiClient.createModifier(domain: domain, request: request)
            notificationManager.show(title: "Modifier created", color: .green)
            return Result(id: id, seed: makePreviewSeed())
        } catch {
            fieldError = error.localizedDescription
            return nil
        }
    }

    /// Keeps mock URL/headers/body from the creation seed and syncs form metadata.
    private func makePreviewSeed() -> ModifierCreationSeed {
        let resolvedURL: String
        if seed.mockId != nil || seed.url != ModifierCreationSeed.empty.url {
            resolvedURL = seed.url
        } else {
            let normalizedPath = path.hasPrefix("/") ? path : "/" + path
            resolvedURL = "https://example.com\(normalizedPath)"
        }
        return ModifierCreationSeed(
            mockId: sampleMockRequestId.isEmpty ? nil : sampleMockRequestId,
            url: resolvedURL,
            path: path,
            method: method,
            scenario: scenario,
            requestHeadersJSON: seed.requestHeadersJSON,
            requestBody: seed.requestBody
        )
    }
}
