//
//  ScenarioModel.swift
//  
//
//  Created by Yusuf Özgül on 8.11.2023.
//

import Foundation

public struct ScenarioModel: Codable {
    public let deviceId: String
    public let path: String
    public let method: String?
    public let scenario: String
    public let mockDomain: String
}
