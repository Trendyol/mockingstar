//
//  MockModel.swift
//
//
//  Created by Yusuf Özgül on 31.08.2023.
//

import AnyCodable
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

    enum CodingKeys: String, CodingKey {
        case metaData
        case requestHeader
        case responseHeader
        case requestBody
        case responseBody

        static let allFieldsWithoutResponseBody: [CodingKeys] = [.metaData, .responseHeader, .requestHeader, .requestBody]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metaData = try container.decode(MockModelMetaData.self, forKey: .metaData)
        let requestHeader: MockModelHeader = try container.decode(MockModelHeader.self, forKey: .requestHeader)
        let responseHeader: MockModelHeader = try container.decode(MockModelHeader.self, forKey: .responseHeader)
        let requestBody: MockModelBody = try container.decode(MockModelBody.self, forKey: .requestBody)

        self.requestBody = requestBody.description
        self.responseHeader = responseHeader.description
        self.requestHeader = requestHeader.description
        metaData.requestBodyType = requestBody.type

        if decoder.userInfo[.lazyDecoding] as? Bool != true {
            let responseBody: MockModelBody = try container.decode(MockModelBody.self, forKey: .responseBody)
            self.responseBody = responseBody.description
            metaData.responseBodyType = responseBody.type
        } else {
            self.responseBody = ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metaData, forKey: .metaData)

        let requestBody: MockModelBody = try .from(string: self.requestBody)
        let responseBody: MockModelBody = try .from(string: self.responseBody)

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

extension MockModel: LazyDecodingModel {
    public func decode(from data: Data) throws {
        guard responseBody.isEmpty else { return }

        do {
            try tryLazyDecode(data: data)
            let _ = try JSONSerialization.jsonObject(with: responseBody.data(using: .utf8) ?? Data())
            metaData.responseBodyType = .json
        } catch {
            Logger(category: "MockModel").warning("Failed to lazy decode mock model, falling back to fully decoding. It may cause performance issues. Mock Id: \(metaData.id) \(error)")
            let decodedMock = try JSONDecoder.shared.decode(MockModel.self, from: data)
            responseBody = decodedMock.responseBody
            metaData.responseBodyType = decodedMock.metaData.responseBodyType
        }
    }

    private func tryLazyDecode(data: Data) throws {
        let mock = String(data: data, encoding: .utf8).orEmpty
        let fieldDefinitions = [" \"%@\" :", " \"%@\":"]

        guard let responseBodyStart: Range = fieldDefinitions.firstMapped(transform: {
            mock.firstRange(of: String(format: $0, CodingKeys.responseBody.rawValue))
        }) else {
            throw NSError(domain: "MockModel", code: -1)
        }

        let nextFields = CodingKeys.allFieldsWithoutResponseBody.flatMap { key in
            fieldDefinitions.map { fieldDefinition in
                (key, fieldDefinition)
            }
        }

        let nextFieldStarts = nextFields.compactMap {
            let range = mock.firstRange(of: String(format: $0.1, $0.0.rawValue))

            guard let range else { return nil as Range<String.Index>? }
            guard responseBodyStart.upperBound < range.lowerBound else { return nil as Range<String.Index>? }

            return range
        }

        guard let nextFieldStart = nextFieldStarts.min(by: { $0.lowerBound < $1.lowerBound }) else {
            throw NSError(domain: "MockModel", code: -2)
        }

        guard responseBodyStart.upperBound < nextFieldStart.lowerBound else { throw NSError(domain: "MockModel", code: -3) }
        responseBody = String(mock[responseBodyStart.upperBound...nextFieldStart.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines).dropLast())
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
    public internal(set) var requestBodyType: MockModelBodyType?
    public internal(set) var responseBodyType: MockModelBodyType?

    enum CodingKeys: String, CodingKey {
        case url
        case method
        case appendTime
        case updateTime
        case httpStatus
        case responseTime
        case scenario
        case id
    }

    public init(url: URL,
                method: String,
                appendTime: Date,
                updateTime: Date,
                httpStatus: Int,
                responseTime: Double,
                scenario: String,
                id: String = UUID().uuidString,
                requestBodyType: MockModelBodyType? = nil,
                responseBodyType: MockModelBodyType? = nil) {
        self.url = url
        self.method = method
        self.appendTime = appendTime
        self.updateTime = updateTime
        self.httpStatus = httpStatus
        self.responseTime = responseTime
        self.scenario = scenario
        self.id = id
        self.requestBodyType = requestBodyType
        self.responseBodyType = responseBodyType
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(URL.self, forKey: .url)
        method = try container.decode(String.self, forKey: .method)
        appendTime = try container.decode(Date.self, forKey: .appendTime)
        updateTime = try container.decode(Date.self, forKey: .updateTime)
        httpStatus = try container.decode(Int.self, forKey: .httpStatus)
        responseTime = try container.decode(Double.self, forKey: .responseTime)
        scenario = try container.decode(String.self, forKey: .scenario)
        id = try container.decode(String.self, forKey: .id)
        requestBodyType = nil
        responseBodyType = nil
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        MockModelMetaData(url: url,
                          method: method,
                          appendTime: appendTime,
                          updateTime: updateTime,
                          httpStatus: httpStatus,
                          responseTime: responseTime,
                          scenario: scenario,
                          id: id,
                          requestBodyType: requestBodyType,
                          responseBodyType: responseBodyType)
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

        if fileName.count > 256 {
            logger.warning("File name length is out of limit. Trying to reduce...")
            fileName = shortFilename
        }

        return fileName
    }

    private var shortFilename: String {
        var fileName = ""

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

public enum MockModelBodyType {
    case null, json, html, xml, graphql, text
}

public enum MockModelBodyValidationError: Error, LocalizedError {
    case invalidJSON(String)
    case dataConversionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let message):
            return "JSON validation failed: \(message)"
        case .dataConversionFailed:
            return "Converting to data failed"
        }
    }
}

public extension MockModelBodyType {
    func validate(body: String) throws {
        switch self {
        case .json:
            try jsonValidator(body)
        case .null, .text, .html, .xml, .graphql:
            break
        }
    }

    private func jsonValidator(_ body: String) throws {
        guard !body.isEmpty else { return }
        guard let data = body.data(using: .utf8) else {
            throw MockModelBodyValidationError.dataConversionFailed
        }

        do {
            let _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            let nsError = error as NSError
            let errorMessage = nsError.userInfo["NSDebugDescription"] as? String ?? "NO DEBUG ERROR"
            throw MockModelBodyValidationError.invalidJSON(errorMessage)
        }
    }
}

public extension MockModelBodyType? {
    func validate(body: String) throws {
        try self?.validate(body: body)
    }
}

public enum MockModelBody: Codable, CustomStringConvertible {
    case null
    case json(AnyCodableModel)
    case html(String)
    case xml(String)
    case graphql(String)
    case text(String)

    public var description: String {
        switch self {
        case .null: ""
        case .json(let json): json.description
        case .html(let html): html
        case .xml(let xml): xml
        case .graphql(let graphql): graphql
        case .text(let text): text
        }
    }

    public var type: MockModelBodyType {
        switch self {
        case .null: .null
        case .json: .json
        case .html: .html
        case .xml: .xml
        case .graphql: .graphql
        case .text: .text
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let jsonValue = try? container.decode(AnyCodableModel.self),
           jsonValue.description != "Not Valid JSON" {
            self = .json(jsonValue)
            return
        }

        if let stringValue = try? container.decode(String.self) {
            self = try Self.parseContent(from: stringValue)
            return
        }

        throw DecodingError.typeMismatch(MockModelBody.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode MockModelBody"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .json(let json):
            try container.encode(json)
        case .html(let html):
            try container.encode(html)
        case .xml(let xml):
            try container.encode(xml)
        case .graphql(let graphql):
            try container.encode(graphql)
        case .text(let text):
            try container.encode(text)
        }
    }

    public static func from(string: String) throws -> MockModelBody {
        try parseContent(from: string)
    }

    private static func parseContent(from string: String) throws -> MockModelBody {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedString.isEmpty {
            return .null
        }

        if let json = try? AnyCodableModel(jsonText: trimmedString) {
            return .json(json)
        }

        if trimmedString.hasPrefix("<") && trimmedString.hasSuffix(">") {
            let lowercased = trimmedString.lowercased()
            if lowercased.contains("<!doctype html") ||
                lowercased.contains("<html") ||
                lowercased.contains("<head>") ||
                lowercased.contains("<body>") {
                return .html(string)
            } else {
                return .xml(string)
            }
        }

        if (trimmedString.contains("query") && (trimmedString.contains("{") || trimmedString.contains("("))) ||
            (trimmedString.contains("mutation") && (trimmedString.contains("{") || trimmedString.contains("("))) ||
            (trimmedString.contains("subscription") && (trimmedString.contains("{") || trimmedString.contains("("))) {
            return .graphql(string)
        }

        return .text(string)
    }
}
