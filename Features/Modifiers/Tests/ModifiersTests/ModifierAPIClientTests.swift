import CommonKit
import Server
import XCTest
@testable import Modifiers

final class MockModifierAPIClientTests: XCTestCase {
    private func modifier() -> MockModifierModel {
        .init(id: "product", path: "/products/42", method: "GET", transformerCode: "function transformer(req, chain) { return chain.proceed(req); }")
    }

    func test_listAndGet_UseDefaultDeviceAndReturnCoreModels() async throws {
        let handler = RecordingModifierHandler()
        handler.model = modifier()
        let client = MockModifierAPIClient(handler: handler)

        let list = try await client.listModifiers(domain: "Test")
        let model = try await client.getModifier(domain: "Test", id: "product")

        XCTAssertEqual(list, [modifier()])
        XCTAssertEqual(model, modifier())
        XCTAssertEqual(handler.calls, ["list", "get"])
        XCTAssertEqual(handler.domain, "Test")
        XCTAssertEqual(handler.deviceId, "")
        XCTAssertEqual(handler.id, "product")
    }

    func test_createUpdateAndDelete_ForwardDefinitionsAndRenameIDs() async throws {
        let handler = RecordingModifierHandler()
        let client = MockModifierAPIClient(handler: handler)
        var request = MockModifierWriteRequest(id: "product", path: "/products/42", method: "GET", transformerCode: "draft")

        try await client.createModifier(domain: "Test", request: request)
        XCTAssertEqual(handler.model, request.asModel(id: "product"))
        request.id = "renamed"
        try await client.updateModifier(domain: "Test", id: "product", request: request)
        XCTAssertEqual(handler.id, "product")
        XCTAssertEqual(handler.model?.id, "renamed")
        request.id = nil
        try await client.updateModifier(domain: "Test", id: "renamed", request: request)
        XCTAssertEqual(handler.model?.id, "renamed")
        try await client.deleteModifier(domain: "Test", id: "renamed")

        XCTAssertEqual(handler.calls, ["create", "update", "update", "delete"])
        XCTAssertEqual(handler.domain, "Test")
        XCTAssertEqual(handler.id, "renamed")
    }

    func test_activation_PreservesSourcesAndTargetsDefaultDevice() async throws {
        let handler = RecordingModifierHandler()
        let client = MockModifierAPIClient(handler: handler)
        let activations = [MockModifierActivation(id: "product", source: .mock), .init(id: "another", source: .live)]

        try await client.setActiveModifiers(domain: "Test", activations: activations)

        XCTAssertEqual(handler.activations, activations)
        XCTAssertEqual(handler.domain, "Test")
        XCTAssertEqual(handler.deviceId, "")
    }

    func test_preview_ForwardsUnsavedDraftWithoutCreatingOrUpdating() async throws {
        let handler = RecordingModifierHandler()
        let client = MockModifierAPIClient(handler: handler)
        let preview = MockModifierPreviewRequest(
            currentModifierId: "product",
            modifier: .init(id: "product", path: "/products/42", method: "GET", transformerCode: "unsaved draft"),
            request: .init(url: try XCTUnwrap(URL(string: "https://example.com/products/42")), method: "GET"),
            source: .live
        )

        let response = try await client.previewModifier(domain: "Test", request: preview)

        XCTAssertEqual(response, handler.previewResponse)
        XCTAssertEqual(handler.preview, preview)
        XCTAssertEqual(handler.calls, ["preview"])
        XCTAssertEqual(handler.domain, "Test")
        XCTAssertEqual(handler.deviceId, "")
    }

    func test_coreErrors_MapToUIErrors() async {
        let handler = RecordingModifierHandler()
        let client = MockModifierAPIClient(handler: handler)
        let cases: [(ServerMockModifierError, MockModifierAPIError)] = [
            (.alreadyExists("product"), .conflict),
            (.notFound("product"), .notFound),
            (.invalidId("../product"), .badRequest),
            (.unknownIds(["product"]), .badRequest),
            (.duplicateIds, .badRequest),
            (.previewInvalidRequest("invalid"), .badRequest),
            (.previewNotFound("missing"), .notFound),
            (.previewConflict("renamed"), .conflict),
            (.previewExecutionFailed("script failed"), .executionFailed("script failed")),
            (.previewLiveRequestFailed("network failed"), .liveRequestFailed("network failed"))
        ]
        for (error, expected) in cases {
            handler.error = error
            do {
                _ = try await client.listModifiers(domain: "Test")
                XCTFail("Expected core error")
            } catch {
                XCTAssertEqual(error as? MockModifierAPIError, expected)
            }
        }
    }

    func test_missingModelAndMissingCreationID_AreRejected() async {
        let handler = RecordingModifierHandler()
        let client = MockModifierAPIClient(handler: handler)
        do {
            _ = try await client.getModifier(domain: "Test", id: "missing")
            XCTFail("Expected not found")
        } catch {
            XCTAssertEqual(error as? MockModifierAPIError, .notFound)
        }
        do {
            try await client.createModifier(domain: "Test", request: .init(path: "/products/42", method: "GET", transformerCode: "draft"))
            XCTFail("Expected invalid creation ID")
        } catch {
            XCTAssertEqual(error as? MockModifierAPIError, .badRequest)
        }
        XCTAssertEqual(handler.calls, ["get"])
    }
}

private final class RecordingModifierHandler: ServerMockModifierHandlerInterface {
    var calls: [String] = []
    var domain: String?
    var deviceId: String?
    var id: String?
    var model: MockModifierModel?
    var activations: [MockModifierActivation]?
    var preview: MockModifierPreviewRequest?
    var error: Error?
    let previewResponse = MockModifierPreviewResponse(status: 200, headers: [:], bodyBase64: "")

    private func record(_ operation: String, domain: String, deviceId: String? = nil, id: String? = nil) throws {
        calls.append(operation)
        self.domain = domain
        self.deviceId = deviceId
        self.id = id
        if let error { throw error }
    }

    func listModifiers(domain: String, deviceId: String) async throws -> [MockModifierModel] {
        try record("list", domain: domain, deviceId: deviceId)
        return model.map { [$0] } ?? []
    }

    func getModifier(domain: String, id: String, deviceId: String) async throws -> MockModifierModel? {
        try record("get", domain: domain, deviceId: deviceId, id: id)
        return model
    }

    func createModifier(domain: String, model: MockModifierModel) async throws {
        try record("create", domain: domain)
        self.model = model
    }

    func updateModifier(domain: String, currentId: String, model: MockModifierModel) async throws {
        try record("update", domain: domain, id: currentId)
        self.model = model
    }

    func deleteModifier(domain: String, id: String) async throws {
        try record("delete", domain: domain, id: id)
    }

    func setActiveModifiers(domain: String, deviceId: String, activations: [MockModifierActivation]) async throws {
        try record("activate", domain: domain, deviceId: deviceId)
        self.activations = activations
    }

    func previewModifier(domain: String, deviceId: String, request: MockModifierPreviewRequest) async throws -> MockModifierPreviewResponse {
        try record("preview", domain: domain, deviceId: deviceId)
        preview = request
        return previewResponse
    }
}
