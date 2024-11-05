//
//  Dictionary+Extension.swift
//  CommonKit
//
//  Created by Yusuf Özgül on 5.11.2024.
//

import Foundation

public extension Dictionary where Key == String, Value == String {
    func caseInsensitiveSearch(for key: String) -> String? {
        guard let value = self.first(where: { NSString(string: $0.key).caseInsensitiveCompare(key) == .orderedSame })?.value else { return nil }
        return value.isEmpty ? nil : value
    }
}
