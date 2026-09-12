import XCTest
@testable import Modifiers

final class UserDefaultsAPIKeyStoreTests: XCTestCase {
    func test_saveLoadClear_RoundTripsWithoutEmptyStrings() throws {
        let suite = "modifier.apikey.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsAPIKeyStore(defaults: defaults)

        XCTAssertNil(store.load())
        try store.save("  sk-test  ")
        XCTAssertEqual(store.load(), "sk-test")
        try store.clear()
        XCTAssertNil(store.load())
        try store.save("")
        XCTAssertNil(store.load())
    }
}
