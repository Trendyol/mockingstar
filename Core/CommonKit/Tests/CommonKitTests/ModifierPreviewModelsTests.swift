import XCTest
@testable import CommonKit

final class MockModifierPreviewModelsTests: XCTestCase {
    func test_previewMetadata_CodableAndWriteMappingPreserveEmptyScenario() throws {
        let request = MockModifierWriteRequest(id: "preview", path: "/widgets", method: "GET",
            previewCurl: "curl 'https://example.com/widgets?q=1'", previewSource: .live, previewScenario: "",
            transformerCode: "function transformer(req, chain) { return chain.proceed(req); }")
        let decoded = try JSONDecoder().decode(MockModifierWriteRequest.self, from: JSONEncoder().encode(request))
        XCTAssertEqual(decoded, request)
        let model = decoded.asModel(id: "preview")
        XCTAssertEqual(model.previewCurl, request.previewCurl)
        XCTAssertEqual(model.previewSource, .live)
        XCTAssertEqual(model.previewScenario, "")
        XCTAssertFalse(model.enabled)
        XCTAssertNil(model.source)
    }

    func test_previewRequest_CodableRoundTrip_PreservesDraftAndBinaryBody() throws {
        let request = MockModifierPreviewRequest(
            currentModifierId: "discount",
            modifier: .init(
                id: "discount-v2",
                path: "/cart",
                method: "GET",
                scenario: "checkout",
                order: 2,
                sampleMockRequestId: "mock-1",
                transformerCode: "function transformer(req, chain) { return chain.proceed(req) }"
            ),
            request: .init(
                url: try XCTUnwrap(URL(string: "https://example.com/cart")),
                method: "GET",
                scenario: "checkout",
                headers: ["Accept": "application/json"],
                bodyBase64: Data("body".utf8).base64EncodedString()
            ),
            source: .mock
        )

        let data = try JSONEncoder().encode(request)
        XCTAssertEqual(try JSONDecoder().decode(MockModifierPreviewRequest.self, from: data), request)
    }

    func test_creationSeed_FromMock_CopiesRequestFields() throws {
        let mock = MockModel(
            metaData: .init(
                url: try XCTUnwrap(URL(string: "https://example.com/cart?item=1")),
                method: "POST",
                appendTime: .init(timeIntervalSince1970: 1),
                updateTime: .init(timeIntervalSince1970: 2),
                httpStatus: 200,
                responseTime: 0,
                scenario: "checkout",
                id: "mock-1"
            ),
            requestHeader: "{\"Accept\":\"application/json\"}",
            responseHeader: "{}",
            requestBody: "{\"id\":1}",
            responseBody: "{}"
        )

        let seed = MockModifierCreationSeed(mock: mock)

        XCTAssertEqual(seed.mockId, "mock-1")
        XCTAssertEqual(seed.url, "https://example.com/cart?item=1")
        XCTAssertEqual(seed.path, "/cart")
        XCTAssertEqual(seed.method, "POST")
        XCTAssertEqual(seed.scenario, "checkout")
        XCTAssertEqual(seed.requestHeadersJSON, "{\"Accept\":\"application/json\"}")
        XCTAssertEqual(seed.requestBody, "{\"id\":1}")
    }
}
