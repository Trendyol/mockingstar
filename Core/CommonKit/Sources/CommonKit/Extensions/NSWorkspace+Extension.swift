//
//  NSWorkspace+Extension.swift
//
//
//  Created by Yusuf Özgül on 4.12.2023.
//

#if os(macOS)
import Foundation
import AppKit

public protocol NSWorkspaceInterface {
    @discardableResult func selectFile(_ fullPath: String?, inFileViewerRootedAtPath rootFullPath: String) -> Bool
}

extension NSWorkspace: NSWorkspaceInterface {}
#endif
