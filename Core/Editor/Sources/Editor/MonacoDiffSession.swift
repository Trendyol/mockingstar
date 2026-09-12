import CommonKit
import SwiftUI
import WebKit

public final class MonacoDiffSession {
    private let bridge: MonacoDiffWebView

    var webView: WKWebView { bridge.webView }

    public var onEditPath: ((Int) -> Void)? {
        get { bridge.onEditPath }
        set { bridge.onEditPath = newValue }
    }

    public init() {
        bridge = MonacoDiffWebView()
    }

    public func setDiff(original: String?, modified: String, type: MockModelBodyType) {
        bridge.setDiff(original: original ?? modified, modified: modified, language: type.monacoLanguageId)
    }
}

final class MonacoDiffWebView: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let webView: WKWebView
    var onEditPath: ((Int) -> Void)?

    private var pendingOriginal = ""
    private var pendingModified = ""
    private var pendingLanguage = "plaintext"
    private var isLoaded = false

    override init() {
        webView = WKWebView()
        super.init()
        webView.navigationDelegate = self
        guard let url = Bundle.module.url(forResource: "diff", withExtension: "html", subdirectory: "MonacoEditor") else { return }
        webView.load(URLRequest(url: url))
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        webView.configuration.userContentController.add(self, name: "editPath")
        webView.isInspectable = true
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "editPath")
    }

    func setDiff(original: String, modified: String, language: String) {
        pendingOriginal = original
        pendingModified = modified
        pendingLanguage = language
        guard isLoaded else { return }
        push()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded = true
        push()
    }

    private func push() {
        let originalB64 = pendingOriginal.data(using: .utf8)?.base64EncodedString() ?? ""
        let modifiedB64 = pendingModified.data(using: .utf8)?.base64EncodedString() ?? ""
        webView.runJS("setLanguage('\(pendingLanguage)')")
        webView.runJS("setDiffContent(`\(originalB64)`, `\(modifiedB64)`)")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "editPath" else { return }
        let offset: Int?
        if let number = message.body as? NSNumber {
            offset = number.intValue
        } else if let string = message.body as? String {
            offset = Int(string)
        } else {
            offset = nil
        }
        guard let offset else { return }
        onEditPath?(offset)
    }
}

public struct MonacoDiffView: NSViewRepresentable {
    private let session: MonacoDiffSession

    public init(session: MonacoDiffSession) {
        self.session = session
    }

    public func makeNSView(context: Context) -> WKWebView {
        session.webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {}
}
