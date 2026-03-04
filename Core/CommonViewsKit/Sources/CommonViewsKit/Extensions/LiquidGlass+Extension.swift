//
//  LiquidGlass+Extension.swift
//  CommonViewsKit
//
//  Created by Yusuf Tayyip Özgül on 26.02.2026.
//

import SwiftUI

public extension ToolbarContent {
    func disableSharedBackground() -> some ToolbarContent {
        if #available(macOS 26.0, *) {
            return self.sharedBackgroundVisibility(.hidden)
        } else {
            return self
        }
    }
}
