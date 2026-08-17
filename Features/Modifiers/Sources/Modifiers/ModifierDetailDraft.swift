import CommonKit
import Foundation

struct ModifierDetailDraft: Equatable {
    var id: String
    var path: String
    var method: String
    var scenario: String
    var order: Int
    var sampleMockRequestId: String
    var transformerCode: String

    init(model: ModifierModel) {
        id = model.id
        path = model.path
        method = model.method
        scenario = model.scenario ?? ""
        order = model.order
        sampleMockRequestId = model.sampleMockRequestId ?? ""
        transformerCode = model.transformerCode
    }

    var writeRequest: ModifierWriteRequest {
        .init(
            id: id,
            path: path,
            method: method.uppercased(),
            scenario: scenario.isEmpty ? nil : scenario,
            order: max(1, order),
            sampleMockRequestId: sampleMockRequestId.isEmpty ? nil : sampleMockRequestId,
            transformerCode: transformerCode
        )
    }
}

struct ModifierPreviewInput: Equatable, Codable {
    var source: ModifierPreviewSource
    var url: String
    var method: String
    var scenario: String
    var headersJSON: String
    var body: String

    static func initial(model: ModifierModel, seed: ModifierCreationSeed?) -> Self {
        if let seed {
            return .init(
                source: seed.mockId == nil ? .live : .mock,
                url: seed.url,
                method: seed.method,
                scenario: seed.scenario,
                headersJSON: normalizedHeadersJSON(seed.requestHeadersJSON),
                body: seed.requestBody
            )
        }
        return .init(
            source: model.sampleMockRequestId == nil ? .live : .mock,
            url: "https://example.com\(model.path)",
            method: model.method,
            scenario: model.scenario ?? "",
            headersJSON: "{}",
            body: ""
        )
    }

    /// Prefer a compact JSON object string so the headers field round-trips through `JSONDecoder`.
    private static func normalizedHeadersJSON(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              let encoded = try? JSONSerialization.data(
                  withJSONObject: dictionary.mapValues { "\($0)" },
                  options: [.sortedKeys, .withoutEscapingSlashes]
              ),
              let json = String(data: encoded, encoding: .utf8) else {
            return trimmed.isEmpty ? "{}" : raw
        }
        return json
    }
}

enum ModifierPreviewInputStore {
    private static func key(domain: String, id: String) -> String {
        "modifier.previewInput.\(domain).\(id)"
    }

    static func save(
        _ input: ModifierPreviewInput,
        domain: String,
        id: String,
        defaults: UserDefaults = .standard
    ) {
        guard let data = try? JSONEncoder().encode(input) else { return }
        defaults.set(data, forKey: key(domain: domain, id: id))
    }

    static func load(
        domain: String,
        id: String,
        defaults: UserDefaults = .standard
    ) -> ModifierPreviewInput? {
        guard let data = defaults.data(forKey: key(domain: domain, id: id)) else { return nil }
        return try? JSONDecoder().decode(ModifierPreviewInput.self, from: data)
    }

    static func remove(
        domain: String,
        id: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.removeObject(forKey: key(domain: domain, id: id))
    }
}
