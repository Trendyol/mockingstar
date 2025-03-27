//
//  MockServerFlags.swift
//
//
//  Created by Yusuf Özgül on 9.09.2023.
//

import Foundation

public struct MockServerFlags: CustomStringConvertible {
    let mockSource: MockSource
    let scenario: String?
    let domain: String
    let deviceId: String

    public var description: String {
        "Flags: source: \(mockSource), scenario: \(scenario ?? "nil"), domain: \(domain), deviceId: \(deviceId)"
    }

    public init(mockSource: MockSource, scenario: String?, domain: String, deviceId: String) {
        self.mockSource = mockSource
        self.scenario = scenario
        self.domain = domain
        self.deviceId = deviceId
    }

    /// onlyMock: never use live environment
    /// onlyLive: never use mock response
    /// `default`: prefer mock response
    public enum MockSource {
        case onlyMock
        case onlyLive
        case `default`

        public init(from rawFlags: [String:String]) {
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
