//
//  EditorSession.swift
//
//
//  Created by Yusuf Özgül on 3.08.2026.
//

import CommonKit
import WebKit

public final class EditorSession {
    public let content: EditorContent
    private let bridge: EditorWebView

    public var isReadOnly: Bool {
        get { bridge.isReadOnly }
        set { bridge.setReadOnly(newValue) }
    }

    var webView: WKWebView { bridge.webView }

    public init(content: EditorContent = .init(), isReadOnly: Bool = false) {
        self.content = content
        bridge = EditorWebView(content: content, isReadOnly: isReadOnly)
    }

    public func setContent(_ value: String, type: MockModelBodyType) {
        content.type = type
        content.content = value
    }

    static let prewarmed = EditorSession()
}
