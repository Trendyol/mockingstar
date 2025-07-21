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
            DispatchQueue.global(qos: .userInteractive).async {
                self.onContentChange?()
                self.onContentDidChange?()
            }
        }
    }
    public var type: MockModelBodyType = .json {
        didSet {
            guard type != oldValue else { return }
            DispatchQueue.global(qos: .userInteractive).async {
                self.onLanguageChange?()
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
    public init() {}

    public func makeNSView(context: NSViewRepresentableContext<EditorView>) -> WKWebView {
        EditorWebView.shared.webView
    }

    public func updateEditorContent(contentModel: EditorContent) {
        EditorWebView.shared.content = contentModel
        contentModel.onContentChange = {
            EditorWebView.shared.updateContent()
        }
        contentModel.onLanguageChange = {
            EditorWebView.shared.updateLanguage()
        }
        EditorWebView.shared.setInitialContent()
        EditorWebView.shared.updateLanguage()
    }

    public func updateNSView(_ nsView: WKWebView, context: NSViewRepresentableContext<EditorView>) { }
    public func makeCoordinator() -> Coordinator { Coordinator() }
    public class Coordinator {  }

    public static func warmUp() {
        let _ = EditorWebView.shared
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
        }
    }
}
