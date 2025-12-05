//
//  HeaderFilter.swift
//
//
//  Created by Yusuf Özgül on 31.08.2023.
//

import Foundation

final class HeaderFilter {
    class func filter(_ headers: [String: String]) -> [String: String] {
        headers.filter { key, value in
            !["Content-Encoding", "Transfer-Encoding"].contains(key)
        }
    }
}
