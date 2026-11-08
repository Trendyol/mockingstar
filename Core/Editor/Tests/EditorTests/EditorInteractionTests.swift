import WebKit
import XCTest
@testable import Editor

@MainActor
final class EditorInteractionTests: XCTestCase {
    func test_formatJavaScript_UpdatesContentPreservesBehaviorAndCanBeUndone() async throws {
        let code = "function transformer(req,chain){/* keep */var res=chain.proceed(req);res.body.title='Elbise';return res;}"
        let session = EditorSession(content: .init(content: code, type: .javascript))
        try await waitForJavaScript(
            "typeof monacoEditor !== 'undefined' && monacoEditor.getModel().getLanguageId() === 'javascript' && monacoEditor.getAction('editor.action.formatDocument').isSupported()",
            in: session.webView
        )
        try await session.formatDocument()
        try await waitForJavaScript("monacoEditor.getValue().includes('res.body.title =')", in: session.webView)
        let value = try await session.webView.evaluateJavaScript("monacoEditor.getValue()")
        let formatted = try XCTUnwrap(value as? String)
        XCTAssertTrue(formatted.contains("/* keep */"))
        let title = try await session.webView.evaluateJavaScript("new Function(monacoEditor.getValue() + '; return transformer({}, {proceed: () => ({body:{}})}).body.title;')()")
        XCTAssertEqual(title as? String, "Elbise")
        XCTAssertEqual(session.content.content, formatted)
        _ = try await session.webView.evaluateJavaScript("monacoEditor.trigger('test', 'undo', null)")
        let restored = try await session.webView.evaluateJavaScript("monacoEditor.getValue()")
        XCTAssertEqual(restored as? String, code)
    }

    func test_readOnlyEditor_RejectsFormattingWithoutChangingContent() async throws {
        let session = EditorSession(content: .init(content: "var a=1;", type: .javascript), isReadOnly: true)
        try await waitForJavaScript("typeof monacoEditor !== 'undefined' && monacoEditor.getOption(monaco.editor.EditorOption.readOnly)", in: session.webView)
        do {
            try await session.formatDocument()
            XCTFail("Read-only content must not be formatted")
        } catch {
            XCTAssertEqual(session.content.content, "var a=1;")
        }
    }

    func test_responseDiff_CommandFFindsInBothReadOnlyPanes() async throws {
        let session = MonacoDiffSession()
        session.setDiff(original: "{\"original\":1}", modified: "{\"transformed\":2}", type: .json)
        try await waitForJavaScript("typeof diffEditor !== 'undefined' && diffEditor !== null && originalModel !== null", in: session.webView)
        for side in ["getOriginalEditor", "getModifiedEditor"] {
            _ = try await session.webView.evaluateJavaScript("""
                var ed = diffEditor.\(side)();
                ed.focus();
                ed.getDomNode().querySelector('textarea').dispatchEvent(new KeyboardEvent('keydown', {
                    key: 'f', code: 'KeyF', keyCode: 70, which: 70,
                    metaKey: true, bubbles: true, cancelable: true
                }));
                """)
            let revealed = try await session.webView.evaluateJavaScript("diffEditor.\(side)().getContribution('editor.contrib.findController').getState().isRevealed")
            XCTAssertEqual(revealed as? Bool, true, "Command-F must open search in \(side)")
        }
    }

    private func waitForJavaScript(_ condition: String, in webView: WKWebView) async throws {
        for _ in 0..<150 {
            if (try? await webView.evaluateJavaScript(condition)) as? Bool == true { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("Editor did not become ready: \(condition)")
        throw NSError(domain: "EditorInteractionTests", code: 1)
    }
}
