//
//  Editor.swift
//  
//
//  Created by Yusuf Özgül on 9.08.2023.
//

import SwiftUI
import WebKit

@Observable
public class DiffEditorContent {
    public var leftSideContent: String = ""
    public var rightSideContent: String = ""
    public var shouldHideLeftSide: Bool = false
    public var shouldHideRightSide: Bool = false
    public var diffCount: String = ""

    @ObservationIgnored
    var onContentChange: (() -> Void)? = nil

    public init(leftSideContent: String = "", rightSideContent: String = "" ) {
        self.leftSideContent = leftSideContent
        self.rightSideContent = rightSideContent
    }

    public func update() {
        onContentChange?()
    }
}

public struct DiffEditorView: NSViewRepresentable {
    private let contentModel: DiffEditorContent

    public init(contentModel: DiffEditorContent) {
        self.contentModel = contentModel
    }

    public func makeNSView(context: NSViewRepresentableContext<DiffEditorView>) -> WKWebView {
        DiffEditorWebView.shared.content = contentModel
        contentModel.onContentChange = {
            DiffEditorWebView.shared.updateContent()
        }
        DiffEditorWebView.shared.setInitialContent()
        DiffEditorWebView.shared.getDiffCount { count in
            self.contentModel.diffCount = count
        }
        return DiffEditorWebView.shared.webView
    }

    public func updateEditorContent(contentModel: DiffEditorContent) {
        DiffEditorWebView.shared.content = contentModel
        contentModel.onContentChange = {
            DiffEditorWebView.shared.updateContent()
        }
        DiffEditorWebView.shared.setInitialContent()
    }

    public func updateNSView(_ nsView: WKWebView, context: NSViewRepresentableContext<DiffEditorView>) { }
    public func makeCoordinator() -> Coordinator { Coordinator() }
    public class Coordinator {  }
}
