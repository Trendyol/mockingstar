//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 4.09.2023.
//

import Foundation

public extension Optional<String> {
    var orEmpty: String {
        self ?? ""
    }

    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

public extension String {
    var encodedUrlPathValue: String {
        self
            .components(separatedBy: "/")
            .drop(while: \.isEmpty)
            .compactMap { $0.addingPercentEncoding(withAllowedCharacters: .alphanumerics) }
            .joined(separator: "/")
    }
}
