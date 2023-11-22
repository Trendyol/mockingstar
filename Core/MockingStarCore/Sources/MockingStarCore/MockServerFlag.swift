//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 9.09.2023.
//

import Foundation

struct MockServerFlags {
    let disableLiveEnvironment: Bool
    let scenario: String?
    let shouldNotMock: Bool
    let domain: String
    let deviceId: String
}
