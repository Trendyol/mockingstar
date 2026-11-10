import CommonKit
import CommonViewsKitTestSupport
import XCTest
@testable import Modifiers

@MainActor
final class MockModifierCreateViewModelTests: XCTestCase {
    func test_create_WithoutMockLeavesPreviewURLBlank() async {
        let sut = MockModifierCreateViewModel(
            seed: .empty,
            apiClient: FakeMockModifierAPIClient(),
            notificationManager: MockNotificationManager()
        )
        sut.modifierId = "product"
        sut.path = "/products/42"

        let result = await sut.create(domain: "Dev")

        XCTAssertEqual(result?.seed.url, "")
        XCTAssertEqual(result?.seed.path, "/products/42")
    }

    func test_mockSeed_PrefillsMetadataAndPreview() {
        let seed = MockModifierCreationSeed(
            mockId: "mock-1",
            url: "https://example.com/cart",
            path: "/cart",
            method: "POST",
            scenario: "checkout",
            requestHeadersJSON: "{\"Accept\":\"application/json\"}",
            requestBody: "{\"id\":1}"
        )

        let sut = MockModifierCreateViewModel(
            seed: seed,
            apiClient: FakeMockModifierAPIClient(),
            notificationManager: MockNotificationManager()
        )

        XCTAssertEqual(sut.path, "/cart")
        XCTAssertEqual(sut.method, "POST")
        XCTAssertEqual(sut.scenario, "checkout")
        XCTAssertEqual(sut.sampleMockRequestId, "mock-1")
    }

    func test_create_SendsInactivePassThroughModifierAndReturnsSeed() async {
        let api = FakeMockModifierAPIClient()
        let seed = MockModifierCreationSeed(
            mockId: "mock-1",
            url: "https://real.example/cart?x=1",
            path: "/cart",
            method: "GET",
            requestHeadersJSON: "{\"Accept\":\"application/json\"}",
            requestBody: "{\"id\":1}"
        )
        let sut = MockModifierCreateViewModel(
            seed: seed,
            apiClient: api,
            notificationManager: MockNotificationManager()
        )
        sut.modifierId = "cart-modifier"

        let result = await sut.create(domain: "Dev")

        XCTAssertEqual(api.invokedCreate?.id, "cart-modifier")
        XCTAssertEqual(api.invokedCreate?.sampleMockRequestId, "mock-1")
        XCTAssertEqual(
            api.invokedCreate?.transformerCode,
            """
            function transformer(req, chain) {
              var res = chain.proceed(req);

              return res;
            }
            """
        )
        XCTAssertEqual(result?.id, "cart-modifier")
        XCTAssertEqual(result?.seed.url, "https://real.example/cart?x=1")
        XCTAssertEqual(result?.seed.requestHeadersJSON, "{\"Accept\":\"application/json\"}")
        XCTAssertEqual(result?.seed.requestBody, "{\"id\":1}")
        XCTAssertNil(api.invokedSetActiveActivations)
    }

    func test_importCurl_PrefillsMetadataAndPersistsPreviewOnCreate() async throws {
        let api = FakeMockModifierAPIClient()
        let sut = MockModifierCreateViewModel(seed: .empty, apiClient: api, notificationManager: MockNotificationManager())
        sut.curlCommand = #"curl 'https://example.com/search/widgets?q=elbise' -H 'X-Merlin-Scenario: dress' --json '{"query":"elbise"}' --compressed"#

        sut.importCurl()

        XCTAssertEqual(sut.modifierId, "search-widgets")
        XCTAssertEqual(sut.path, "/search/widgets")
        XCTAssertEqual(sut.method, "POST")
        XCTAssertEqual(sut.scenario, "dress")
        XCTAssertTrue(sut.importedCurl)
        XCTAssertNil(sut.curlError)
        _ = await sut.create(domain: "Dev")
        let created = try XCTUnwrap(api.invokedCreate)
        let preview = try XCTUnwrap(MockModifierPreviewInput.saved(model: created.asModel(id: "search-widgets")))
        XCTAssertEqual(preview.url, "https://example.com/search/widgets?q=elbise")
        XCTAssertEqual(preview.method, "POST")
        XCTAssertEqual(preview.body, #"{"query":"elbise"}"#)
        XCTAssertEqual(preview.source, .live)
        XCTAssertEqual(preview.scenario, "dress")
        XCTAssertNil(api.invokedSetActiveActivations)
    }

    func test_importCurl_PreservesManualIDAndOrderClearsMismatchedSample() {
        let sut = MockModifierCreateViewModel(
            seed: .init(mockId: "cart-mock", url: "https://example.com/cart", path: "/cart"),
            apiClient: FakeMockModifierAPIClient(), notificationManager: MockNotificationManager()
        )
        sut.modifierId = "custom"
        sut.order = 3
        sut.curlCommand = "curl https://example.com/widgets"
        sut.importCurl()
        XCTAssertEqual(sut.modifierId, "custom")
        XCTAssertEqual(sut.order, 3)
        XCTAssertEqual(sut.sampleMockRequestId, "")

        sut.curlCommand = "curl '"
        sut.importCurl()
        XCTAssertNotNil(sut.curlError)
        XCTAssertEqual(sut.path, "/widgets")
        XCTAssertEqual(sut.modifierId, "custom")
    }
}
