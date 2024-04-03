//
//  WebView.swift
//
//
//  Created by Yusuf Özgül on 25.07.2023.
//

import SwiftUI
import WebKit

final class JSONEditorWebView: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    static var shared = JSONEditorWebView()
    private(set) var webView: WKWebView = WKWebView()
    var content: JSONEditorContent? = nil
    private var lastEditorContent = ""

    private override init() {
        super.init()
        createEditor()
    }

    private func createEditor() {
        webView.navigationDelegate = self
        webView.uiDelegate = self
        guard let url = Bundle.module.url(forResource: "main", withExtension: "html", subdirectory: "MonacoEditor") else { return }
        webView.load(URLRequest(url: url))
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        webView.configuration.userContentController.add(self, name: "updateText")
        webView.isInspectable = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        setInitialContent()
    }

    func setInitialContent() {
        let base64 = content?.content.data(using: .utf8)?.base64EncodedString() ?? ""
        webView.runJS("setEditorContent(`\(base64)`)")
    }

    func updateContent() {
        guard let content = content, lastEditorContent != content.content else { return }
        lastEditorContent = content.content
        let base64 = content.content.data(using: .utf8)?.base64EncodedString() ?? ""

        DispatchQueue.main.async {
            self.webView.runJS("setEditorContent(`\(base64)`)")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let message = message.body as? String, message != content?.content else { return }
        content?.content = message
        lastEditorContent = message
    }
}

extension WKWebView {
    func runJS(_ javaScriptString: String) {
        guard Thread.isMainThread else {
            return DispatchQueue.main.async { [weak self] in
                self?.runJS(javaScriptString)
            }
        }
        evaluateJavaScript(javaScriptString, completionHandler: nil)
    }
}
