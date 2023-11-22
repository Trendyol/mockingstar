//
//  JsonEncoder+Extension.swift
//
//
//  Created by Yusuf Özgül on 9.09.2023.
//

import Foundation

public extension JSONEncoder {
    static let shared: JSONEncoder = {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        encoder.dateEncodingStrategy = .formatted(formatter)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()
}
