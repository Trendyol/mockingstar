//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 31.08.2023.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension HTTPURLResponse {
    var headersDictionary: [String: String] {
        var dict: [String: String] = [:]
        for header in allHeaderFields {
            guard let key = header.key as? String,
                  let value = header.value as? String
            else {
                continue
            }
            dict[key] = value
        }

        return dict
    }
}
