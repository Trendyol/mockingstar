import CommonKit
import CommonViewsKitTestSupport
import XCTest
@testable import Modifiers

@MainActor
final class ModifierCreateViewModelTests: XCTestCase {
    func test_mockSeed_PrefillsMetadataAndPreview() {
        let seed = ModifierCreationSeed(
            mockId: "mock-1",
            url: "https://example.com/cart",
            path: "/cart",
            method: "POST",
            scenario: "checkout",
            requestHeadersJSON: "{\"Accept\":\"application/json\"}",
            requestBody: "{\"id\":1}"
        )

        let sut = ModifierCreateViewModel(
            seed: seed,
            apiClient: MockModifierAPIClient(),
            notificationManager: MockNotificationManager()
        )

        XCTAssertEqual(sut.path, "/cart")
        XCTAssertEqual(sut.method, "POST")
        XCTAssertEqual(sut.scenario, "checkout")
        XCTAssertEqual(sut.sampleMockRequestId, "mock-1")
    }

    func test_create_SendsInactivePassThroughModifierAndReturnsSeed() async {
        let api = MockModifierAPIClient()
        let seed = ModifierCreationSeed(
            mockId: "mock-1",
            url: "https://real.example/cart?x=1",
            path: "/cart",
            method: "GET",
            requestHeadersJSON: "{\"Accept\":\"application/json\"}",
            requestBody: "{\"id\":1}"
        )
        let sut = ModifierCreateViewModel(
            seed: seed,
            apiClient: api,
            notificationManager: MockNotificationManager()
        )
        sut.modifierId = "cart-modifier"

        let result = await sut.create(domain: "Dev")

        XCTAssertEqual(api.invokedCreate?.id, "cart-modifier")
        XCTAssertEqual(api.invokedCreate?.sampleMockRequestId, "mock-1")
        XCTAssertTrue(api.invokedCreate?.transformerCode.contains("chain.proceed") == true)
        XCTAssertEqual(result?.id, "cart-modifier")
        XCTAssertEqual(result?.seed.url, "https://real.example/cart?x=1")
        XCTAssertEqual(result?.seed.requestHeadersJSON, "{\"Accept\":\"application/json\"}")
        XCTAssertEqual(result?.seed.requestBody, "{\"id\":1}")
        XCTAssertNil(api.invokedSetActiveIds)
    }
}
