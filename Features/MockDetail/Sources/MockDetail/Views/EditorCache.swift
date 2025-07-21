//
//  JsonEditorCache.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 21.09.2023.
//

import DiffEditor
import Editor
import SwiftUI

final class JsonEditorCache {
    static let shared = JsonEditorCache()
    let editor: EditorView
    var content: EditorContent = .init(content: "") {
        didSet { updateContent() }
    }

    private init() {
        editor = EditorView()
    }

    private func updateContent() {
        editor.updateEditorContent(contentModel: content)
    }
}

final class DiffEditorCache {
    static let shared = DiffEditorCache()
    let editor: DiffEditorView
    var content: DiffEditorContent = .init() {
        didSet { updateContent() }
    }

    private init() {
        editor = DiffEditorView(contentModel: content)
    }

    private func updateContent() {
        editor.updateEditorContent(contentModel: content)
    }
}
