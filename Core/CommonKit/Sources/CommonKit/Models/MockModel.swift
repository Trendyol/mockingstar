//
//  MockModel.swift
//
//
//  Created by Yusuf Özgül on 31.08.2023.
//

import AnyCodable
import Foundation

public typealias MockModelHeader = [String: String]
public typealias MockModelHeaderString = String
private let logger = Logger(category: "MockModel")

/// A model representing a mock.
public final class MockModel: Codable, Identifiable, NSCopying {
    public var id: String { metaData.id }

    public var metaData: MockModelMetaData
    public var requestHeader: MockModelHeaderString
    public var responseHeader: MockModelHeaderString
    public var requestBody: String
    public var responseBody: String
    public var fileURL: URL?

    public init(
        metaData: MockModelMetaData,
        requestHeader: MockModelHeaderString,
        responseHeader: MockModelHeaderString,
        requestBody: String,
        responseBody: String,
        fileURL: URL? = nil
    ) {
        self.metaData = metaData
        self.requestHeader = requestHeader
        self.responseHeader = responseHeader
        self.requestBody = requestBody
        self.responseBody = responseBody
        self.fileURL = fileURL
    }

    enum CodingKeys: CodingKey {
        case metaData
        case requestHeader
        case responseHeader
        case requestBody
        case responseBody
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metaData = try container.decode(MockModelMetaData.self, forKey: .metaData)
        let requestHeader: MockModelHeader = try container.decode(MockModelHeader.self, forKey: .requestHeader)
        let responseHeader: MockModelHeader = try container.decode(MockModelHeader.self, forKey: .responseHeader)
        let requestBody: AnyCodableModel = try container.decode(AnyCodableModel.self, forKey: .requestBody)
        let responseBody: AnyCodableModel = try container.decode(AnyCodableModel.self, forKey: .responseBody)

        self.requestBody = requestBody.description
        self.responseBody = responseBody.description
        self.responseHeader = responseHeader.description
        self.requestHeader = requestHeader.description
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metaData, forKey: .metaData)

        let requestBody: AnyCodableModel
        if self.requestBody.isEmpty {
            requestBody = .init(NSNull())
        } else {
            requestBody = try .init(jsonText: self.requestBody)
        }

        let responseBody: AnyCodableModel
        if self.responseBody.isEmpty {
            responseBody = .init(NSNull())
        } else {
            responseBody = try .init(jsonText: self.responseBody)
        }

        try container.encode(requestBody, forKey: .requestBody)
        try container.encode(responseBody, forKey: .responseBody)

        let requestHeader: MockModelHeader = try .initWithJson(requestHeader)
        let responseHeader: MockModelHeader = try .initWithJson(responseHeader)

        try container.encode(requestHeader, forKey: .requestHeader)
        try container.encode(responseHeader, forKey: .responseHeader)
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        MockModel(metaData: metaData.copy(with: zone) as! MockModelMetaData,
                  requestHeader: requestHeader,
                  responseHeader: responseHeader,
                  requestBody: requestBody,
                  responseBody: responseBody,
                  fileURL: fileURL)
    }
}

// MARK: - Equatable
extension MockModel: Equatable {
    public static func == (lhs: MockModel, rhs: MockModel) -> Bool {
        lhs.metaData == rhs.metaData &&
        lhs.requestHeader == rhs.requestHeader &&
        lhs.responseHeader == rhs.responseHeader &&
        lhs.requestBody == rhs.requestBody &&
        lhs.responseBody == rhs.responseBody
    }
}

// MARK: - Hashable
extension MockModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(metaData)
        hasher.combine(requestHeader)
        hasher.combine(responseHeader)
        hasher.combine(requestBody)
        hasher.combine(responseBody)
    }
}

/// A model representing a Mock Detail Metadata.
public class MockModelMetaData: Codable, Identifiable, NSCopying {
    public var url: URL
    public var method: String
    public let appendTime: Date
    public var updateTime: Date
    public var httpStatus: Int
    public var responseTime: Double
    public var scenario: String
    public var id: String

    public init(url: URL,
                method: String,
                appendTime: Date,
                updateTime: Date,
                httpStatus: Int,
                responseTime: Double,
                scenario: String,
                id: String = UUID().uuidString) {
        self.url = url
        self.method = method
        self.appendTime = appendTime
        self.updateTime = updateTime
        self.httpStatus = httpStatus
        self.responseTime = responseTime
        self.scenario = scenario
        self.id = id
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        MockModelMetaData(url: url,
                          method: method,
                          appendTime: appendTime,
                          updateTime: updateTime,
                          httpStatus: httpStatus,
                          responseTime: responseTime,
                          scenario: scenario,
                          id: id)
    }
}

// MARK: - Equatable
extension MockModelMetaData: Equatable {
    public static func == (lhs: MockModelMetaData, rhs: MockModelMetaData) -> Bool {
        lhs.url == rhs.url &&
        lhs.method == rhs.method &&
        lhs.appendTime == rhs.appendTime &&
        lhs.updateTime == rhs.updateTime &&
        lhs.httpStatus == rhs.httpStatus &&
        lhs.responseTime == rhs.responseTime &&
        lhs.scenario == rhs.scenario &&
        lhs.id == rhs.id
    }
}

// MARK: - Hashable
extension MockModelMetaData: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(method)
        hasher.combine(appendTime)
        hasher.combine(updateTime)
        hasher.combine(httpStatus)
        hasher.combine(responseTime)
        hasher.combine(scenario)
        hasher.combine(id)
    }
}

// MARK: - Utils
public extension MockModel {
    
    /// Mock detail file should be proper file name, it's important for find and return mocks.
    ///
    /// Mock Detail File name rule:
    ///
    /// `request path` + `request scenario (if contains) ` + `mock id`
    var fileName: String {
        var fileName = cleanPath.replacingOccurrences(of: "/", with: "+") + "_"

        if !metaData.scenario.isEmpty {
            fileName += metaData.scenario + "_"
        }

        fileName += metaData.id
        fileName += ".json"

        return fileName
    }
    
    ///  Mock detail file should be proper path, it's important for find and return mocks.
    ///
    /// Mock Detail File path rule:
    /// `request path` + `request HTTP method`
    var folderPath: String {
        cleanPath + "/" + metaData.method.uppercased()
    }

    ///  Mock detail file should be proper path, it's important for find and return mocks.
    ///
    /// Mock Detail File path rule:
    ///
    /// ``folderPath``  + ``fileName``
    var filePath: String {
        folderPath + "/" + fileName
    }

    private var cleanPath: String {
        if metaData.url.path().isEmpty || metaData.url.path() == "/" {
            return (metaData.url.host() ?? metaData.url.absoluteString)
        }

        return metaData.url.path().encodedUrlPathValue
    }
}

extension MockModelHeader {
    /// JSON representation of headers
    public var description: String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            logger.error("Error converting to JSON")
            return "Error converting to JSON"
        } catch {
            logger.error("Error converting to JSON: \(error).")
            return "Error converting to JSON: \(error)."
        }
    }
    
    /// JSON representation headers to key value dictionary header
    /// - Parameter jsonText: JSON text headers
    /// - Returns: Key-value header dictionary
    public static func initWithJson(_ jsonText: String) throws -> MockModelHeader {
        guard let data = jsonText.data(using: .utf8) else {
            logger.error("MockModelHeader convert data error")
            throw NSError(domain: "MockModelHeader", code: -1)
        }

        return try JSONDecoder().decode(Self.self, from: data)
    }
}

public extension MockModel {
    /// URLRequest representation mock model
    var asURLRequest: URLRequest {
        var request = URLRequest(url: metaData.url)
        request.allHTTPHeaderFields = try? requestHeader.asDictionary()
        request.httpMethod = metaData.method

        if !requestBody.isEmpty {
            request.httpBody = requestBody.data(using: .utf8)
        }

        return request
    }
}

public extension MockModelHeaderString {
    func asDictionary() throws -> MockModelHeader {
        try .initWithJson(self)
    }

    init(_ dictionary: MockModelHeader) {
        self.init(dictionary.description)
    }
}
