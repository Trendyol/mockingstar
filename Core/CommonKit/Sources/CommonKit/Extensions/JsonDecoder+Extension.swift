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
        formatter.locale = Locale(identifier: "en_US_POSIX")
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()

    static func custom(_ userInfo: [CodingUserInfoKey: any Sendable]) -> JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        decoder.dateDecodingStrategy = .formatted(formatter)
        decoder.userInfo = userInfo
        return decoder
    }

    
}
