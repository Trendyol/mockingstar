//
//  LiquidGlass+Extension.swift
//  CommonViewsKit
//
//  Created by Yusuf Tayyip Özgül on 26.02.2026.
//

import SwiftUI

struct RemoveSharedBackgroundWrapper<Content: ToolbarContent>: ToolbarContent {
    let content: Content
    
    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26, macOS 26, *) {
            content.sharedBackgroundVisibility(.hidden)
        } else {
            content
        }
    }
}

public extension ToolbarContent {
    func disableSharedBackground() -> some ToolbarContent {
        RemoveSharedBackgroundWrapper(content: self)
    }
}
