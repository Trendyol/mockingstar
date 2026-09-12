import XCTest
@testable import CommonKit

final class ModifierMatcherTests: XCTestCase {
    private let matcher = ModifierMatcher()

    private func mod(id: String, path: String = "/users", method: String = "GET",
                     scenario: String? = nil, order: Int = 1) -> ModifierModel {
        ModifierModel(id: id, path: path, method: method, scenario: scenario,
                      enabled: true, order: order, transformerCode: "//")
    }

    func test_match_FiltersByExactPathAndMethod() {
        let mods = [
            mod(id: "a", path: "/users", method: "GET"),
            mod(id: "b", path: "/users", method: "POST"),
            mod(id: "c", path: "/other", method: "GET"),
        ]
        let result = matcher.match(modifiers: mods, path: "/users", method: "get", scenario: nil)
        XCTAssertEqual(result.map(\.id), ["a"])
    }

    func test_match_NullScenarioMatchesAny() {
        let mods = [mod(id: "any", scenario: nil)]
        XCTAssertEqual(matcher.match(modifiers: mods, path: "/users", method: "GET", scenario: "promo").map(\.id), ["any"])
        XCTAssertEqual(matcher.match(modifiers: mods, path: "/users", method: "GET", scenario: nil).map(\.id), ["any"])
    }

    func test_match_StringScenarioExactOnly() {
        let mods = [mod(id: "promo", scenario: "promo")]
        XCTAssertEqual(matcher.match(modifiers: mods, path: "/users", method: "GET", scenario: "promo").map(\.id), ["promo"])
        XCTAssertTrue(matcher.match(modifiers: mods, path: "/users", method: "GET", scenario: "other").isEmpty)
        XCTAssertTrue(matcher.match(modifiers: mods, path: "/users", method: "GET", scenario: nil).isEmpty)
    }

    func test_match_SortsByOrderThenId() {
        let mods = [
            mod(id: "b", order: 2),
            mod(id: "a", order: 2),
            mod(id: "z", order: 1),
        ]
        XCTAssertEqual(matcher.match(modifiers: mods, path: "/users", method: "GET", scenario: nil).map(\.id), ["z", "a", "b"])
    }

    func test_match_DoesNotFilterByEnabledFlag() {
        // Activation is owned by the per-device set; matcher receives only active definitions.
        let mods = [mod(id: "on").withEnabled(false)]
        XCTAssertEqual(matcher.match(modifiers: mods, path: "/users", method: "GET", scenario: nil).map(\.id), ["on"])
    }
}

private extension ModifierModel {
    func withEnabled(_ enabled: Bool) -> ModifierModel {
        ModifierModel(id: id, path: path, method: method, scenario: scenario,
                      enabled: enabled, order: order, sampleMockRequestId: sampleMockRequestId,
                      transformerCode: transformerCode)
    }
}
