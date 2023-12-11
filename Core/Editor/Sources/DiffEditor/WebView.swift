//
//  File.swift
//
//
//  Created by Yusuf Özgül on 9.08.2023.
//

import SwiftUI
import WebKit
import Combine

final class DiffEditorWebView: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    static var shared = DiffEditorWebView()
    private(set) var webView: WKWebView = WKWebView()
    var content: DiffEditorContent? = nil
    private var leftSideLastEditorContent = ""
    private var rightSideLastEditorContent = ""
    private var diffCountBlock: ((String) -> Void)? = nil

    private override init() {
        super.init()
        createEditor()
    }

    private func createEditor() {
        webView.navigationDelegate = self
        webView.uiDelegate = self
        guard let url = Bundle.module.url(forResource: "diff", withExtension: "html", subdirectory: "DiffEditor") else { return }
        webView.load(URLRequest(url: url))
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        webView.configuration.userContentController.add(self, name: "leftUpdate")
        webView.configuration.userContentController.add(self, name: "rightUpdate")
        webView.isInspectable = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        setInitialContent()
        webView.runJS("aceDiffer.editors.left.ace.clearSelection()")
        webView.runJS("aceDiffer.editors.right.ace.clearSelection()")
    }

    func setInitialContent() {
        updateContent(forced: true)
    }

    func updateContent(forced: Bool = false) {
        if let content = content?.leftSideContent, leftSideLastEditorContent != content || forced {
            leftSideLastEditorContent = content
            let script = "aceDiffer.editors.left.ace.setValue(String.raw`\(content)`)"
            webView.runJS(script)

            webView.runJS("aceDiffer.editors.left.ace.clearSelection()")
        }

        if let content = content?.rightSideContent, rightSideLastEditorContent != content || forced  {
            rightSideLastEditorContent = content
            let script = "aceDiffer.editors.right.ace.setValue(String.raw`\(content)`)"
            webView.runJS(script)

            webView.runJS("aceDiffer.editors.right.ace.clearSelection()")
        }

        if content?.shouldHideLeftSide ?? false {
            webView.runJS("document.getElementsByClassName('acediff__left ace_editor ace-twilight')[0].style.display = 'none'")
        } else {
            webView.runJS("document.getElementsByClassName('acediff__left ace_editor ace-twilight')[0].style.display = ''")
        }

        if content?.shouldHideRightSide ?? false {
            webView.runJS("document.getElementsByClassName('acediff__right ace_editor ace-twilight')[0].style.display = 'none'")
        } else {
            webView.runJS("document.getElementsByClassName('acediff__right ace_editor ace-twilight')[0].style.display = ''")
        }

        if let content, !content.shouldHideLeftSide, !content.shouldHideRightSide {
            webView.runJS("document.getElementsByClassName('acediff__gutter')[0].style.display = ''", completionHandler: nil)
        } else {
            webView.runJS("document.getElementsByClassName('acediff__gutter')[0].style.display = 'none'", completionHandler: nil)
        }
    }

    func getDiffCount(diffCount: @escaping (String) -> Void) {
        diffCountBlock = diffCount
        webView.runJS("aceDiffer.getNumDiffs()") { result, _ in
            guard let result = result as? Int else { return }
            diffCount(String(result))
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }

        switch message.name {
        case "leftUpdate":
            content?.leftSideContent = body
            leftSideLastEditorContent = body
        case "rightUpdate":
            content?.rightSideContent = body
            rightSideLastEditorContent = body
        default: break
        }

        webView.runJS("aceDiffer.getNumDiffs()") { result, _ in
            guard let result = result as? Int else { return }
            self.diffCountBlock?(String(result))
        }
    }
}

extension WKWebView {
    func runJS(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)?) {
        guard Thread.isMainThread else {
            return DispatchQueue.main.async { [weak self] in
                self?.runJS(javaScriptString, completionHandler: completionHandler)
            }
        }

        evaluateJavaScript(javaScriptString, completionHandler: completionHandler)
    }

    func runJS(_ javaScriptString: String) {
        guard Thread.isMainThread else {
            return DispatchQueue.main.async { [weak self] in
                self?.runJS(javaScriptString)
            }
        }
        evaluateJavaScript(javaScriptString, completionHandler: nil)
    }
}
