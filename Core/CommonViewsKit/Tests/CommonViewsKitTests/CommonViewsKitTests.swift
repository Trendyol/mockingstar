import XCTest
@testable import CommonViewsKit

final class CommonViewsKitTests: XCTestCase {
    func test_replaceLast_ReplacesOnlyFinalRoute() {
        let store = NavigationStore()
        store.path = [.modifiers, .modifier(id: "old")]

        store.replaceLast(with: .modifier(id: "new"))

        XCTAssertEqual(store.path, [.modifiers, .modifier(id: "new")])
    }

    func test_replaceLast_EmptyPathOpensRoute() {
        let store = NavigationStore()
        store.replaceLast(with: .modifier(id: "new"))
        XCTAssertEqual(store.path, [.modifier(id: "new")])
    }
}
