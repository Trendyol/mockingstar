//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 2.09.2023.
//

import Foundation

public extension Collection {
    /// Access collection index safely
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
