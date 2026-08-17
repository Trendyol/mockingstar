//
//  HandleModifierTests.swift
//
//
//  Created for Partial Mock Modifier feature.
//

import XCTest
import FlyingFox
import CommonKit
@testable import Server

final class HandleModifierTests: XCTestCase {
    private var sut: HandleModifier!
    private var mockHandler: MockModifierHandler!
    private let jsonEncoder = JSONEncoder()

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = HandleModifier()
        mockHandler = MockModifierHandler()
        HandleModifier.handler = mockHandler
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        sut = nil
        HandleModifier.handler = nil
    }

    private func sampleModifier(id: String = "test-modifier") -> ModifierModel {
        .init(id: id, path: "/users/1", method: "GET", scenario: nil, enabled: false, order: 1, sampleMockRequestId: nil, transformerCode: "function transformer(req, chain) { return chain.proceed(req) }")
    }

    private func writeRequest(id: String? = "test-modifier") -> ModifierWriteRequest {
        .init(id: id, path: "/users/1", method: "GET", scenario: nil, order: 1, sampleMockRequestId: nil, transformerCode: "function transformer(req, chain) { return chain.proceed(req) }")
    }

    private func makePreviewRequest() -> ModifierPreviewRequest {
        ModifierPreviewRequest(
            currentModifierId: "discount",
            modifier: .init(
                id: "discount",
                path: "/cart",
                method: "GET",
                order: 1,
                sampleMockRequestId: "mock-1",
                transformerCode: "function transformer(req, chain) { return chain.proceed(req) }"
            ),
            request: .init(
                url: URL(string: "https://example.com/cart")!,
                method: "GET"
            ),
            source: .mock
        )
    }

    // MARK: - GET /modifiers

    func test_handleRequest_GETList_ReturnsModifiers() async throws {
        mockHandler.stubbedListResult = [sampleModifier()]
        let request = HTTPRequest.make(method: .GET, path: "/modifiers")

        let response = try await sut.handleRequest(request)

        XCTAssertEqual(response.statusCode.code, 200)
        XCTAssertEqual(mockHandler.invokedListParameters?.domain, "Dev")
        XCTAssertEqual(mockHandler.invokedListParameters?.deviceId, "")
        let bodyData = try await response.bodyData
        let decoded = try JSONDecoder().decode([ModifierModel].self, from: bodyData)
        XCTAssertEqual(decoded, [sampleModifier()])
    }

    func test_handleRequest_GETList_UsesDomainAndDeviceId() async throws {
        mockHandler.stubbedListResult = []
        let request = HTTPRequest.make(method: .GET,
                                       path: "/modifiers?domain=Prod",
                                       headers: [HTTPHeader("deviceId"): "device-a"])

        _ = try await sut.handleRequest(request)

        XCTAssertEqual(mockHandler.invokedListParameters?.domain, "Prod")
        XCTAssertEqual(mockHandler.invokedListParameters?.deviceId, "device-a")
    }

    func test_handleRequest_GETList_HandlerNotRegistered() async throws {
        HandleModifier.handler = nil
        let request = HTTPRequest.make(method: .GET, path: "/modifiers")
        let response = try await sut.handleRequest(request)
        XCTAssertEqual(response.statusCode.code, 501)
    }

    // MARK: - GET /modifiers/{id}

    func test_handleRequest_GETById_Found_Returns200() async throws {
        mockHandler.stubbedGetResult = sampleModifier()
        let request = HTTPRequest.make(method: .GET, path: "/modifiers/test-modifier")

        let response = try await sut.handleRequest(request)

        XCTAssertEqual(response.statusCode.code, 200)
        XCTAssertEqual(mockHandler.invokedGetParameters?.domain, "Dev")
        XCTAssertEqual(mockHandler.invokedGetParameters?.id, "test-modifier")
        XCTAssertEqual(mockHandler.invokedGetParameters?.deviceId, "")
    }

    func test_handleRequest_GETById_NotFound_Returns404() async throws {
        mockHandler.stubbedGetResult = nil
        let request = HTTPRequest.make(method: .GET, path: "/modifiers/missing")
        let response = try await sut.handleRequest(request)
        XCTAssertEqual(response.statusCode.code, 404)
    }

    // MARK: - POST /modifiers

    func test_handleRequest_POST_Success_Returns201() async throws {
        let body = try jsonEncoder.encode(writeRequest())
        let request = HTTPRequest.make(method: .POST, path: "/modifiers", body: body)

        let response = try await sut.handleRequest(request)

        XCTAssertEqual(response.statusCode.code, 201)
        XCTAssertEqual(mockHandler.invokedCreateParameters?.domain, "Dev")
        XCTAssertEqual(mockHandler.invokedCreateParameters?.model.id, "test-modifier")
        XCTAssertEqual(mockHandler.invokedCreateParameters?.model.order, 1)
    }

    func test_handleRequest_POST_MissingId_Returns400() async throws {
        let body = try jsonEncoder.encode(writeRequest(id: nil))
        let request = HTTPRequest.make(method: .POST, path: "/modifiers", body: body)
        let response = try await sut.handleRequest(request)
        XCTAssertEqual(response.statusCode.code, 400)
    }

    func test_handleRequest_POST_AlreadyExists_Returns409() async throws {
        let body = try jsonEncoder.encode(writeRequest())
        mockHandler.stubbedCreateError = ServerModifierError.alreadyExists("test-modifier")
        let request = HTTPRequest.make(method: .POST, path: "/modifiers", body: body)
        let response = try await sut.handleRequest(request)
        XCTAssertEqual(response.statusCode.code, 409)
    }

    // MARK: - PUT /modifiers/{id}

    func test_handleRequest_PUTById_UpdatesModifier() async throws {
        let body = try jsonEncoder.encode(writeRequest(id: "test-modifier"))
        let request = HTTPRequest.make(method: .PUT, path: "/modifiers/test-modifier", body: body)

        let response = try await sut.handleRequest(request)

        XCTAssertEqual(response.statusCode.code, 202)
        XCTAssertEqual(mockHandler.invokedUpdateParameters?.currentId, "test-modifier")
        XCTAssertEqual(mockHandler.invokedUpdateParameters?.model.id, "test-modifier")
    }

    func test_handleRequest_PUTById_DifferentBodyIdRequestsRename() async throws {
        let body = try jsonEncoder.encode(writeRequest(id: "renamed"))
        let request = HTTPRequest.make(
            method: .PUT,
            path: "/modifiers/test-modifier",
            body: body
        )

        let response = try await sut.handleRequest(request)

        XCTAssertEqual(response.statusCode.code, 202)
        XCTAssertEqual(mockHandler.invokedUpdateParameters?.currentId, "test-modifier")
        XCTAssertEqual(mockHandler.invokedUpdateParameters?.model.id, "renamed")
    }

    func test_handleRequest_PUTById_RenameConflict_Returns409() async throws {
        mockHandler.stubbedUpdateError = ServerModifierError.alreadyExists("renamed")
        let body = try jsonEncoder.encode(writeRequest(id: "renamed"))
        let request = HTTPRequest.make(
            method: .PUT,
            path: "/modifiers/test-modifier",
            body: body
        )

        let response = try await sut.handleRequest(request)

        XCTAssertEqual(response.statusCode.code, 409)
    }

    // MARK: - PUT /modifiers (active IDs)

    func test_handleRequest_PUTActiveIds_ReplacesDeviceSet() async throws {
        let body = try jsonEncoder.encode(["discount", "latency"])
        let request = HTTPRequest.make(method: .PUT,
                                       path: "/modifiers?domain=Dev",
                                       body: body,
                                       headers: [HTTPHeader("deviceId"): "device-a"])

        let response = try await sut.handleRequest(request)

        XCTAssertEqual(response.statusCode.code, 202)
        XCTAssertEqual(mockHandler.invokedSetActiveParameters?.domain, "Dev")
        XCTAssertEqual(mockHandler.invokedSetActiveParameters?.deviceId, "device-a")
        XCTAssertEqual(mockHandler.invokedSetActiveParameters?.ids, ["discount", "latency"])
    }

    func test_handleRequest_PUTActiveIds_DefaultDomainAndDevice() async throws {
        let body = try jsonEncoder.encode(["discount"])
        let request = HTTPRequest.make(method: .PUT, path: "/modifiers", body: body)

        let response = try await sut.handleRequest(request)

        XCTAssertEqual(response.statusCode.code, 202)
        XCTAssertEqual(mockHandler.invokedSetActiveParameters?.domain, "Dev")
        XCTAssertEqual(mockHandler.invokedSetActiveParameters?.deviceId, "")
    }

    func test_handleRequest_PUTActiveIds_UnknownIds_Returns400() async throws {
        mockHandler.stubbedSetActiveError = ServerModifierError.unknownIds(["missing"])
        let body = try jsonEncoder.encode(["missing"])
        let request = HTTPRequest.make(method: .PUT, path: "/modifiers", body: body)
        let response = try await sut.handleRequest(request)
        XCTAssertEqual(response.statusCode.code, 400)
    }

    // MARK: - DELETE /modifiers/{id}

    func test_handleRequest_DELETEById_Returns202() async throws {
        let request = HTTPRequest.make(method: .DELETE, path: "/modifiers/test-modifier")
        let response = try await sut.handleRequest(request)
        XCTAssertEqual(response.statusCode.code, 202)
        XCTAssertEqual(mockHandler.invokedDeleteParameters?.id, "test-modifier")
    }

    // MARK: - POST /modifiers/preview

    func test_handleRequest_POSTPreview_ReturnsEnvelopeAndUsesDevice() async throws {
        mockHandler.stubbedPreviewResult = .init(
            status: 404,
            headers: ["Content-Type": "application/json"],
            bodyBase64: Data("missing".utf8).base64EncodedString()
        )
        let preview = makePreviewRequest()
        let request = HTTPRequest.make(
            method: .POST,
            path: "/modifiers/preview?domain=Prod",
            body: try jsonEncoder.encode(preview),
            headers: [HTTPHeader("deviceId"): "device-a"]
        )

        let response = try await sut.handleRequest(request)

        XCTAssertEqual(response.statusCode.code, 200)
        XCTAssertEqual(mockHandler.invokedPreviewParameters?.domain, "Prod")
        XCTAssertEqual(mockHandler.invokedPreviewParameters?.deviceId, "device-a")
        let body = try await response.bodyData
        let decoded = try JSONDecoder().decode(ModifierPreviewResponse.self, from: body)
        XCTAssertEqual(decoded.status, 404)
    }

    func test_handleRequest_POSTPreview_ExecutionFailureReturns422JSON() async throws {
        mockHandler.stubbedPreviewError = ServerModifierError.previewExecutionFailed("boom")
        let request = HTTPRequest.make(
            method: .POST,
            path: "/modifiers/preview",
            body: try jsonEncoder.encode(makePreviewRequest())
        )

        let response = try await sut.handleRequest(request)
        let body = try await response.bodyData
        let error = try JSONDecoder().decode(ModifierAPIErrorResponse.self, from: body)

        XCTAssertEqual(response.statusCode.code, 422)
        XCTAssertEqual(response.headers[HTTPHeader("Content-Type")], "application/json")
        XCTAssertEqual(error.code, "execution_failed")
        XCTAssertEqual(error.message, "boom")
    }

    func test_handleRequest_POSTPreview_MapsStructuredErrors() async throws {
        let cases: [(ServerModifierError, Int, String)] = [
            (.previewInvalidRequest("invalid"), 400, "invalid_request"),
            (.previewNotFound("missing"), 404, "not_found"),
            (.previewConflict("exists"), 409, "conflict"),
            (.previewLiveRequestFailed("offline"), 502, "live_proxy_failed")
        ]

        for (serverError, expectedStatus, expectedCode) in cases {
            mockHandler.stubbedPreviewError = serverError
            let request = HTTPRequest.make(
                method: .POST,
                path: "/modifiers/preview",
                body: try jsonEncoder.encode(makePreviewRequest())
            )

            let response = try await sut.handleRequest(request)
            let body = try await response.bodyData
            let envelope = try JSONDecoder().decode(
                ModifierAPIErrorResponse.self,
                from: body
            )

            XCTAssertEqual(response.statusCode.code, expectedStatus)
            XCTAssertEqual(envelope.code, expectedCode)
        }
    }

    // MARK: - Unsupported methods

    func test_handleRequest_DELETEWithoutId_ReturnsMethodNotAllowed() async throws {
        let request = HTTPRequest.make(method: .DELETE, path: "/modifiers")
        let response = try await sut.handleRequest(request)
        XCTAssertEqual(response.statusCode.code, 405)
    }

    func test_handleRequest_PATCH_ReturnsMethodNotAllowed() async throws {
        let request = HTTPRequest.make(method: .PATCH, path: "/modifiers")
        let response = try await sut.handleRequest(request)
        XCTAssertEqual(response.statusCode.code, 405)
    }
}

// MARK: - Mock Handler

private final class MockModifierHandler: ServerModifierHandlerInterface {
    var stubbedListResult: [ModifierModel] = []
    var invokedListParameters: (domain: String, deviceId: String)?

    var stubbedGetResult: ModifierModel?
    var invokedGetParameters: (domain: String, id: String, deviceId: String)?

    var stubbedCreateError: Error?
    var invokedCreateParameters: (domain: String, model: ModifierModel)?

    var stubbedUpdateError: Error?
    var invokedUpdateParameters: (domain: String, currentId: String, model: ModifierModel)?

    var invokedDeleteParameters: (domain: String, id: String)?

    var stubbedSetActiveError: Error?
    var invokedSetActiveParameters: (domain: String, deviceId: String, ids: [String])?

    var stubbedPreviewResult = ModifierPreviewResponse(
        status: 200,
        headers: ["Content-Type": "application/json"],
        bodyBase64: Data("{\"ok\":true}".utf8).base64EncodedString()
    )
    var stubbedPreviewError: Error?
    var invokedPreviewParameters: (
        domain: String,
        deviceId: String,
        request: ModifierPreviewRequest
    )?

    func listModifiers(domain: String, deviceId: String) async throws -> [ModifierModel] {
        invokedListParameters = (domain, deviceId)
        return stubbedListResult
    }

    func getModifier(domain: String, id: String, deviceId: String) async throws -> ModifierModel? {
        invokedGetParameters = (domain, id, deviceId)
        return stubbedGetResult
    }

    func createModifier(domain: String, model: ModifierModel) async throws {
        invokedCreateParameters = (domain, model)
        if let stubbedCreateError { throw stubbedCreateError }
    }

    func updateModifier(domain: String, currentId: String, model: ModifierModel) async throws {
        invokedUpdateParameters = (domain, currentId, model)
        if let stubbedUpdateError { throw stubbedUpdateError }
    }

    func deleteModifier(domain: String, id: String) async throws {
        invokedDeleteParameters = (domain, id)
    }

    func setActiveModifiers(domain: String, deviceId: String, ids: [String]) async throws {
        invokedSetActiveParameters = (domain, deviceId, ids)
        if let stubbedSetActiveError { throw stubbedSetActiveError }
    }

    func previewModifier(
        domain: String,
        deviceId: String,
        request: ModifierPreviewRequest
    ) async throws -> ModifierPreviewResponse {
        invokedPreviewParameters = (domain, deviceId, request)
        if let stubbedPreviewError { throw stubbedPreviewError }
        return stubbedPreviewResult
    }
}
