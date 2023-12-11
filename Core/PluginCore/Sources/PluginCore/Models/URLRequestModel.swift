//
//  URLRequestModel.swift
//  
//
//  Created by Yusuf Özgül on 3.11.2023.
//

import Foundation

/// A model representing a http request.
public struct URLRequestModel: Codable, Equatable {
    public let url: String
    public let headers: [String: String]
    public let body: String
    public let method: String

    public init(url: String, headers: [String : String], body: String, method: String) {
        self.url = url
        self.headers = headers
        self.body = body
        self.method = method
    }
}
