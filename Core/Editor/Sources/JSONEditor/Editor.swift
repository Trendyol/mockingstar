//
//  Editor.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 25.07.2023.
//

import SwiftUI
import WebKit

public class JSONEditorContent {
    public var content: String = "" {
        didSet {
            guard content != oldValue else { return }
            DispatchQueue.global(qos: .userInteractive).async {
                self.onContentChange?()
                self.onContentDidChange?()
            }
        }
    }

    var onContentChange: (() -> Void)? = nil

    public var onContentDidChange: (() -> Void)? = nil

    public init(content: String = "") {
        self.content = content
    }
}

public struct JSONEditorView: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: NSViewRepresentableContext<JSONEditorView>) -> WKWebView {
        JSONEditorWebView.shared.webView
    }

    public func updateEditorContent(contentModel: JSONEditorContent) {
        JSONEditorWebView.shared.content = contentModel
        contentModel.onContentChange = {
            JSONEditorWebView.shared.updateContent()
        }
        JSONEditorWebView.shared.setInitialContent()
    }

    public func updateNSView(_ nsView: WKWebView, context: NSViewRepresentableContext<JSONEditorView>) { }
    public func makeCoordinator() -> Coordinator { Coordinator() }
    public class Coordinator {  }
}
