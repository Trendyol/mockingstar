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
        .init(id: id, path: "/users/1", method: "GET", scenario: nil, enabled: false, priority: 0, sampleMockRequestId: nil, transformerCode: "function transformer(req, chain) { return chain.proceed(req) }")
    }

    // MARK: - GET /modifiers

    func test_handleRequest_GETList_ReturnsModifiers() async throws {
        // Given
        mockHandler.stubbedListResult = [sampleModifier()]

        let request = HTTPRequest.make(method: .GET, path: "/modifiers")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 200)
        XCTAssertEqual(mockHandler.invokedListDomain, "Dev")
        let bodyData = try await response.bodyData
        let decoded = try JSONDecoder().decode([ModifierModel].self, from: bodyData)
        XCTAssertEqual(decoded, [sampleModifier()])
    }

    func test_handleRequest_GETList_UsesDomainQuery() async throws {
        // Given
        mockHandler.stubbedListResult = []

        let request = HTTPRequest.make(method: .GET, path: "/modifiers?domain=Prod")

        // When
        _ = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(mockHandler.invokedListDomain, "Prod")
    }

    func test_handleRequest_GETList_HandlerNotRegistered() async throws {
        // Given
        HandleModifier.handler = nil
        let request = HTTPRequest.make(method: .GET, path: "/modifiers")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 501)
    }

    // MARK: - GET /modifiers/{id}

    func test_handleRequest_GETById_Found_Returns200() async throws {
        // Given
        mockHandler.stubbedGetResult = sampleModifier()

        let request = HTTPRequest.make(method: .GET, path: "/modifiers/test-modifier")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 200)
        XCTAssertEqual(mockHandler.invokedGetParameters?.domain, "Dev")
        XCTAssertEqual(mockHandler.invokedGetParameters?.id, "test-modifier")
        let bodyData = try await response.bodyData
        let decoded = try JSONDecoder().decode(ModifierModel.self, from: bodyData)
        XCTAssertEqual(decoded, sampleModifier())
    }

    func test_handleRequest_GETById_NotFound_Returns404() async throws {
        // Given
        mockHandler.stubbedGetResult = nil

        let request = HTTPRequest.make(method: .GET, path: "/modifiers/missing")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 404)
    }

    // MARK: - POST /modifiers

    func test_handleRequest_POST_Success_Returns201() async throws {
        // Given
        let model = sampleModifier()
        let body = try jsonEncoder.encode(model)

        let request = HTTPRequest.make(method: .POST, path: "/modifiers", body: body)

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 201)
        XCTAssertEqual(mockHandler.invokedCreateParameters?.domain, "Dev")
        XCTAssertEqual(mockHandler.invokedCreateParameters?.model, model)
    }

    func test_handleRequest_POST_AlreadyExists_Returns409() async throws {
        // Given
        let model = sampleModifier()
        let body = try jsonEncoder.encode(model)
        mockHandler.stubbedCreateError = ServerModifierError.alreadyExists(model.id)

        let request = HTTPRequest.make(method: .POST, path: "/modifiers", body: body)

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 409)
    }

    // MARK: - PUT /modifiers/{id}

    func test_handleRequest_PUTById_UpdatesModifier() async throws {
        // Given
        let model = sampleModifier()
        let body = try jsonEncoder.encode(model)

        let request = HTTPRequest.make(method: .PUT, path: "/modifiers/test-modifier", body: body)

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 202)
        XCTAssertEqual(mockHandler.invokedUpdateParameters?.domain, "Dev")
        XCTAssertEqual(mockHandler.invokedUpdateParameters?.model, model)
    }

    // MARK: - PUT /modifiers (bulk)

    func test_handleRequest_PUTBulk_WithDomain_UpdatesThatDomainOnly() async throws {
        // Given
        let update = ModifierBulkUpdate(enabled: true)
        let body = try jsonEncoder.encode(update)

        let request = HTTPRequest.make(method: .PUT, path: "/modifiers?domain=Dev", body: body)

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 202)
        XCTAssertEqual(mockHandler.invokedBulkUpdateParameters?.domain, "Dev")
        XCTAssertEqual(mockHandler.invokedBulkUpdateParameters?.update, update)
    }

    func test_handleRequest_PUTBulk_WithoutDomain_UpdatesAllDomains() async throws {
        // Given
        let update = ModifierBulkUpdate(enabled: false)
        let body = try jsonEncoder.encode(update)

        let request = HTTPRequest.make(method: .PUT, path: "/modifiers", body: body)

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 202)
        XCTAssertNil(mockHandler.invokedBulkUpdateParameters?.domain)
    }

    // MARK: - DELETE /modifiers/{id}

    func test_handleRequest_DELETEById_Returns202() async throws {
        // Given
        let request = HTTPRequest.make(method: .DELETE, path: "/modifiers/test-modifier")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 202)
        XCTAssertEqual(mockHandler.invokedDeleteParameters?.domain, "Dev")
        XCTAssertEqual(mockHandler.invokedDeleteParameters?.id, "test-modifier")
    }

    // MARK: - Unsupported methods

    func test_handleRequest_DELETEWithoutId_ReturnsMethodNotAllowed() async throws {
        // Given
        let request = HTTPRequest.make(method: .DELETE, path: "/modifiers")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 405)
    }

    func test_handleRequest_PATCH_ReturnsMethodNotAllowed() async throws {
        // Given
        let request = HTTPRequest.make(method: .PATCH, path: "/modifiers")

        // When
        let response = try await sut.handleRequest(request)

        // Then
        XCTAssertEqual(response.statusCode.code, 405)
    }
}

// MARK: - Mock Handler

private final class MockModifierHandler: ServerModifierHandlerInterface {
    var stubbedListResult: [ModifierModel] = []
    var invokedListDomain: String?

    var stubbedGetResult: ModifierModel?
    var invokedGetParameters: (domain: String, id: String)?

    var stubbedCreateError: Error?
    var invokedCreateParameters: (domain: String, model: ModifierModel)?

    var stubbedUpdateError: Error?
    var invokedUpdateParameters: (domain: String, model: ModifierModel)?

    var invokedDeleteParameters: (domain: String, id: String)?

    var invokedBulkUpdateParameters: (domain: String?, update: ModifierBulkUpdate)?

    func listModifiers(domain: String) async throws -> [ModifierModel] {
        invokedListDomain = domain
        return stubbedListResult
    }

    func getModifier(domain: String, id: String) async throws -> ModifierModel? {
        invokedGetParameters = (domain, id)
        return stubbedGetResult
    }

    func createModifier(domain: String, model: ModifierModel) async throws {
        invokedCreateParameters = (domain, model)
        if let stubbedCreateError { throw stubbedCreateError }
    }

    func updateModifier(domain: String, model: ModifierModel) async throws {
        invokedUpdateParameters = (domain, model)
        if let stubbedUpdateError { throw stubbedUpdateError }
    }

    func deleteModifier(domain: String, id: String) async throws {
        invokedDeleteParameters = (domain, id)
    }

    func bulkUpdate(domain: String?, update: ModifierBulkUpdate) async throws {
        invokedBulkUpdateParameters = (domain, update)
    }
}
