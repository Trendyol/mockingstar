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

    func firstMapped<T>(transform: (Element) -> T?) -> T? {
        for element in self {
            if let result = transform(element) {
                return result
            }
        }
        return nil
    }
}
