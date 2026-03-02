//
//  LiquidGlass+Extension.swift
//  CommonViewsKit
//
//  Created by Yusuf Tayyip Özgül on 26.02.2026.
//

import SwiftUI

public extension ToolbarContent {
    @ToolbarContentBuilder
    func disableSharedBackground() -> some ToolbarContent {
        if #available(macOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
