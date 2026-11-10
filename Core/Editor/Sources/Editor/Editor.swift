//
//  Editor.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 25.07.2023.
//

import CommonKit
import SwiftUI
import WebKit

public class EditorContent {
    public var content: String = "" {
        didSet {
            guard content != oldValue else { return }
            DispatchQueue.main.async { [weak self] in
                self?.onContentChange?()
                self?.onContentDidChange?()
            }
        }
    }
    public var type: MockModelBodyType = .json {
        didSet {
            guard type != oldValue else { return }
            DispatchQueue.main.async { [weak self] in
                self?.onLanguageChange?()
            }
        }
    }

    var onContentChange: (() -> Void)? = nil
    var onLanguageChange: (() -> Void)? = nil

    public var onContentDidChange: (() -> Void)? = nil

    public init(content: String = "", type: MockModelBodyType = .json) {
        self.content = content
        self.type = type
    }
}

public struct EditorView: NSViewRepresentable {
    private let session: EditorSession

    public init(session: EditorSession) {
        self.session = session
    }

    public func makeNSView(context: Context) -> WKWebView {
        session.webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        session.setContent(session.content.content, type: session.content.type)
        session.isReadOnly = session.isReadOnly
    }

    public static func warmUp() {
        _ = EditorSession.prewarmed
    }
}

// MARK: - MockModelBodyType Extension for Monaco Editor
extension MockModelBodyType {
    /// Convert MockModelBodyType to Monaco Editor language identifier
    var monacoLanguageId: String {
        switch self {
        case .null, .text:
            return "plaintext"
        case .json:
            return "json"
        case .html:
            return "html"
        case .xml:
            return "xml"
        case .graphql:
            return "graphql"
        case .javascript:
            return "javascript"
        }
    }
}
