//
//  EditorCache.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 21.09.2023.
//

import DiffEditor
import SwiftUI

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
