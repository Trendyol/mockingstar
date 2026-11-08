import CommonKit
import Foundation

struct MockModifierDetailDraft: Equatable {
    var id: String
    var path: String
    var method: String
    var scenario: String
    var order: Int
    var sampleMockRequestId: String
    var transformerCode: String
    var previewCurl: String?
    var previewSource: MockModifierPreviewSource?
    var previewScenario: String?

    init(model: MockModifierModel) {
        id = model.id
        path = model.path
        method = model.method
        scenario = model.scenario ?? ""
        order = model.order
        sampleMockRequestId = model.sampleMockRequestId ?? ""
        transformerCode = model.transformerCode
        previewCurl = model.previewCurl
        previewSource = model.previewSource
        previewScenario = model.previewScenario
    }

    var writeRequest: MockModifierWriteRequest {
        .init(
            id: id,
            path: path,
            method: method.uppercased(),
            scenario: scenario.isEmpty ? nil : scenario,
            order: max(1, order),
            sampleMockRequestId: sampleMockRequestId.isEmpty ? nil : sampleMockRequestId,
            previewCurl: previewCurl,
            previewSource: previewSource,
            previewScenario: previewScenario,
            transformerCode: transformerCode
        )
    }
}

struct MockModifierPreviewInput: Equatable, Codable {
    var source: MockModifierPreviewSource
    var url: String
    var method: String
    var scenario: String
    var headersJSON: String
    var body: String

    static func saved(model: MockModifierModel) throws -> Self? {
        guard let curl = model.previewCurl else { return nil }
        let request = try CurlParser(curl).buildRequest()
        let headers = try JSONEncoder().encode(request.allHTTPHeaderFields ?? [:])
        return .init(
            source: model.previewSource ?? (model.sampleMockRequestId == nil ? .live : .mock),
            url: request.url?.absoluteString ?? "",
            method: request.httpMethod ?? model.method,
            scenario: model.previewScenario ?? model.scenario ?? "",
            headersJSON: normalizedHeadersJSON(String(decoding: headers, as: UTF8.self)),
            body: request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        )
    }

    static func initial(model: MockModifierModel, seed: MockModifierCreationSeed?) -> Self {
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
            url: "",
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

enum MockModifierPreviewInputStore {
    private static func key(domain: String, id: String) -> String {
        "modifier.previewInput.\(domain).\(id)"
    }

    static func save(
        _ input: MockModifierPreviewInput,
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
    ) -> MockModifierPreviewInput? {
        guard let data = defaults.data(forKey: key(domain: domain, id: id)) else { return nil }
        return try? JSONDecoder().decode(MockModifierPreviewInput.self, from: data)
    }

    static func remove(
        domain: String,
        id: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.removeObject(forKey: key(domain: domain, id: id))
    }
}
