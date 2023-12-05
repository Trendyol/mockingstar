//
//  NSPasteboard+Extension.swift
//
//
//  Created by Yusuf Özgül on 4.12.2023.
//

import Foundation
import AppKit

public protocol NSPasteboardInterface {
    @discardableResult func clearContents() -> Int
    @discardableResult func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
}

extension NSPasteboard: NSPasteboardInterface {}
