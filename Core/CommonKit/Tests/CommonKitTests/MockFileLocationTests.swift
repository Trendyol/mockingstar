import XCTest
@testable import CommonKit

final class MockFileLocationTests: XCTestCase {
    func test_filePath_UsesRequestPathScenarioAndId() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/cart/items"))
        XCTAssertEqual(
            MockFileLocation.filePath(
                url: url,
                method: "get",
                scenario: "checkout",
                id: "mock-1"
            ),
            "cart/items/GET/cart+items_checkout_mock-1.json"
        )
    }

    func test_filePath_RootRequestUsesHost() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/"))
        XCTAssertEqual(
            MockFileLocation.filePath(url: url, method: "GET", scenario: "", id: "mock-1"),
            "example.com/GET/example.com_mock-1.json"
        )
    }
}
