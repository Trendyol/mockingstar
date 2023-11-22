//
//  JsonDecoder+Extension.swift
//
//
//  Created by Yusuf Özgül on 9.09.2023.
//

import Foundation

public extension JSONDecoder {
    static let shared: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
}
