import XCTest
@testable import Editor

@MainActor
final class EditorSessionTests: XCTestCase {
    func test_sessions_OwnDistinctWebViewsAndContent() {
        let first = EditorSession(content: .init(content: "one", type: .json))
        let second = EditorSession(content: .init(content: "two", type: .javascript))

        XCTAssertFalse(first.webView === second.webView)
        XCTAssertEqual(first.content.content, "one")
        XCTAssertEqual(second.content.content, "two")
    }

    func test_readOnly_CanChangeWithoutReplacingSession() {
        let session = EditorSession(content: .init(content: "{}", type: .json), isReadOnly: true)
        let originalWebView = session.webView

        session.isReadOnly = false

        XCTAssertFalse(session.isReadOnly)
        XCTAssertTrue(originalWebView === session.webView)
    }
}
