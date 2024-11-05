//
//  MockServerFlags.swift
//
//
//  Created by Yusuf Özgül on 9.09.2023.
//

import Foundation

struct MockServerFlags {
    let mockSource: MockSource
    let scenario: String?
    let shouldNotMock: Bool
    let domain: String
    let deviceId: String

    /// onlyMock: never use live environment
    /// onlyLive: never use mock response
    /// `default`: prefer mock response
    enum MockSource {
        case onlyMock
        case onlyLive
        case `default`

        init(from rawFlags: [String:String]) {
            if rawFlags.caseInsensitiveSearch(for: "disableLiveEnvironment") == "true" {
                self = .onlyMock
            } else if rawFlags.caseInsensitiveSearch(for: "disableMockResponse") == "true" {
                self = .onlyLive
            } else {
                self = .default
            }
        }
    }
}
