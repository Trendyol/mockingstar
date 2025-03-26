//
//  ConfigModel.swift
//
//
//  Created by Yusuf Özgül on 1.09.2023.
//

import Foundation

/// Mock decide behaviour configurations
public final class ConfigModel: Codable, Equatable {
    public var pathConfigs: [PathConfigModel] = []
    public var queryConfigs: [QueryConfigModel] = []
    public var headerConfigs: [HeaderConfigModel] = []
    public var mockFilterConfigs: [MockFilterConfigModel] = []
    public var appFilterConfigs: AppConfigModel = AppConfigModel()
    
    /// Initializer of ``ConfigModel``
    /// - Parameters:
    ///   - pathConfigs: ``PathConfigModel`` Path based mock configurations
    ///   - queryConfigs: ``QueryConfigModel`` Query based mock configurations
    ///   - headerConfigs: ``HeaderConfigModel`` Header based mock configurations
    ///   - mockFilterConfigs: ``MockFilterConfigModel`` Mock save filter configurations
    ///   - appFilterConfigs: ``AppConfigModel`` Common mock configurations
    public init(pathConfigs: [PathConfigModel],
                queryConfigs: [QueryConfigModel],
                headerConfigs: [HeaderConfigModel],
                mockFilterConfigs: [MockFilterConfigModel],
                appFilterConfigs: AppConfigModel) {
        self.pathConfigs = pathConfigs
        self.queryConfigs = queryConfigs
        self.headerConfigs = headerConfigs
        self.mockFilterConfigs = mockFilterConfigs
        self.appFilterConfigs = appFilterConfigs
    }

    public init() {}

    public static func == (lhs: ConfigModel, rhs: ConfigModel) -> Bool {
        lhs.pathConfigs == rhs.pathConfigs &&
        lhs.queryConfigs == rhs.queryConfigs &&
        lhs.headerConfigs == rhs.headerConfigs &&
        lhs.mockFilterConfigs == rhs.mockFilterConfigs &&
        lhs.appFilterConfigs == rhs.appFilterConfigs
    }
}

/// Path based mock decide behaviour configurations.
///
/// Path configurations ignore or check all query or header parameters.
///
///> Important: This behaviour can change based on ``AppFilterConfigs.queryFilterDefaultStyleIgnore`` and ``appFilterConfigs.headerFilterDefaultStyleIgnore``. Decider ignores or exact matches all parameters.
///
///
/// ```json
/// {
///     "headerExecuteStyle" : "ignoreAll",
///     "queryExecuteStyle" : "matchAll",
///     "path" : "productDetail/v2/102030/return-conditions"
///  }
/// ```
/// Based on given config model,
/// If path matches `productDetail/v2/*/return-conditions` these two request will be consider same
///
///     - url: https://...../productDetail/v2/102030/return-conditions?type=DigitalService
///     - url: https://...../productDetail/v2/102030/return-conditions?type=Fashion
///
/// Because ``MockingStarCore/MockDecider`` assumes in this path queries are not change request signature.
///
/// Or
/// ```json
/// {
///     "headerExecuteStyle" : "ignoreAll",
///     "queryExecuteStyle" : "matchAll",
///     "path" : "productDetail/v2/*/return-conditions"
///  }
/// ```
/// Based on given config model,
/// If path matches `productDetail/v2/*/return-conditions` these two request will be consider same
///
///     - url: https://...../productDetail/v2/102030/return-conditions?type=DigitalService
///     - url: https://...../productDetail/v2/98765/return-conditions?type=Fashion
///
/// Because ``MockingStarCore/MockDecider`` assumes in this path queries are not change request signature,
/// also there is a path component that path component dynamic and should not change request signature.
///
///> Path Matching Ratio: Whenever Mock configurations expect path, it shouldn't be exact path, ``appFilterConfigs.pathMatchingRatio`` determines path matching ratio.
public final class PathConfigModel: Codable, Equatable, Identifiable, Hashable {
    public var id: String { path + queryExecuteStyle.rawValue + headerExecuteStyle.rawValue }

    public var path: String
    public var queryExecuteStyle: QueryExecuteStyle
    public var headerExecuteStyle: HeaderExecuteStyle

    public init(path: String, queryExecuteStyle: QueryExecuteStyle, headerExecuteStyle: HeaderExecuteStyle) {
        self.path = path
        self.queryExecuteStyle = queryExecuteStyle
        self.headerExecuteStyle = headerExecuteStyle
    }

    public static func == (lhs: PathConfigModel, rhs: PathConfigModel) -> Bool {
        lhs.path == rhs.path &&
        lhs.queryExecuteStyle == rhs.queryExecuteStyle &&
        lhs.headerExecuteStyle == rhs.headerExecuteStyle
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(queryExecuteStyle)
        hasher.combine(headerExecuteStyle)
    }
    
    private enum CodingKeys: CodingKey {
        case path
        case queryExecuteStyle
        case headerExecuteStyle
    }

    private enum Migration_CodingKeys: CodingKey {
        case executeAllQueries
        case executeAllHeaders
    }

    public init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<PathConfigModel.CodingKeys> = try decoder.container(keyedBy: PathConfigModel.CodingKeys.self)
        
        self.path = try container.decode(String.self, forKey: PathConfigModel.CodingKeys.path)

        do {
            self.queryExecuteStyle = try container.decode(QueryExecuteStyle.self, forKey: PathConfigModel.CodingKeys.queryExecuteStyle)
        } catch {
            // Migrate matchAllQueries to QueryExecuteStyle
            let container = try decoder.container(keyedBy: PathConfigModel.Migration_CodingKeys.self)
            let executeAllQueries = (try? container.decode(Bool.self, forKey: PathConfigModel.Migration_CodingKeys.executeAllQueries)) ?? false
            self.queryExecuteStyle = executeAllQueries ? .matchAll : .ignoreAll
        }

        do {
            self.headerExecuteStyle = try container.decode(HeaderExecuteStyle.self, forKey: PathConfigModel.CodingKeys.headerExecuteStyle)
        } catch {
            // Migrate matchAllHeaders to QueryExecuteStyle
            let container = try decoder.container(keyedBy: PathConfigModel.Migration_CodingKeys.self)
            let executeAllHeaders = (try? container.decode(Bool.self, forKey: PathConfigModel.Migration_CodingKeys.executeAllHeaders)) ?? false
            self.headerExecuteStyle = executeAllHeaders ? .matchAll : .ignoreAll
        }
    }
}

/// Query based mock decide behaviour configurations.
///
/// Query configurations ignore or check given query parameters.
///
///> Important: This behaviour can change based on ``appFilterConfigs.queryFilterDefaultStyleIgnore``. Decider ignores or exact matches all parameters.
///
/// ```json
/// {
///      "key" : "type",
///      "path" : [
///        "productDetail/v2/*/return-conditions"
///      ],
///      "value" : ""
/// }
/// ```
/// Based on given config model,
/// These two request will be consider same
///
///     - url: https://...../productDetail/v2/102030/return-conditions?type=DigitalService
///     - url: https://...../productDetail/v2/102030/return-conditions?type=Fashion
///
/// Because ``MockingStarCore/MockDecider`` assumes given query parameters should not be decisive and Mock Decider decide with this information.
///
/// ```json
/// {
///      "key" : "type",
///      "path" : [
///        "productDetail/v2/*/return-conditions"
///      ],
///      "value" : "Fashion"
/// }
/// ```
/// Based on given config model,
/// These two request will be consider **NOT** same
///
///     - url: https://...../productDetail/v2/102030/return-conditions?type=DigitalService
///     - url: https://...../productDetail/v2/102030/return-conditions?type=Fashion
///
/// Because ``MockingStarCore/MockDecider`` assumes given query parameter key=type, value=Fashion should not be decisive and Mock Decider decide with this information but given values not equal.
///
///> Path Matching Ratio: Whenever Mock configurations expect path, it shouldn't be exact path, ``appFilterConfigs.pathMatchingRatio`` determines path matching ratio.
public final class QueryConfigModel: Codable, Equatable, Identifiable, Hashable {
    public var id: String { path.joined() + key + value.orEmpty }

    public var path: [String]
    public var key: String
    public var value: String?

    public init(path: [String] = [], key: String, value: String? = nil) {
        self.path = path
        self.key = key
        self.value = value
    }

    public static func == (lhs: QueryConfigModel, rhs: QueryConfigModel) -> Bool {
        lhs.path == rhs.path &&
        lhs.key == rhs.key &&
        lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(key)
        hasher.combine(value)
    }
}

/// Header based mock decide behaviour configurations.
///
/// Query configurations ignore or check given header parameters.
///
///> Important: This behaviour can change based on ``appFilterConfigs.headerFilterDefaultStyleIgnore``. Decider ignores or exact matches all parameters.
///
/// ```json
/// {
///      "key" : "version",
///      "path" : [
///        "productDetail/v2/*/return-conditions"
///      ],
///      "value" : ""
/// }
/// ```
/// Based on given config model,
/// These two request will be consider same
///
///     - headers: platform=iPhone, version=1.2.3
///     - headers: platform=iPhone
///
/// Because ``MockingStarCore/MockDecider`` assumes given header parameters should not be decisive and Mock Decider decide with this information.
///
/// ```json
/// {
///      "key" : "version",
///      "path" : [
///        "productDetail/v2/*/return-conditions"
///      ],
///      "value" : "1.0.0"
/// }
/// ```
/// Based on given config model,
/// These two request will be consider **NOT** same
///
///     - headers: platform=iPhone, version=1.2.3
///     - headers: platform=iPhone
///
/// Because ``MockingStarCore/MockDecider`` assumes given header parameter key=type, version=1.2.3 should not be decisive and Mock Decider decide with this information but given values not equal.
///
///> Path Matching Ratio: Whenever Mock configurations expect path, it shouldn't be exact path, ``appFilterConfigs.pathMatchingRatio`` determines path matching ratio.
public final class HeaderConfigModel: Codable, Equatable, Identifiable, Hashable {
    public var id: String { path.joined() + key + value.orEmpty }
    
    public var path: [String]
    public var key: String
    public var value: String?

    public init(path: [String] = [], key: String, value: String? = nil) {
        self.path = path
        self.key = key
        self.value = value
    }

    public static func == (lhs: HeaderConfigModel, rhs: HeaderConfigModel) -> Bool {
        lhs.path == rhs.path &&
        lhs.key == rhs.key &&
        lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(key)
        hasher.combine(value)
    }
}

/// Mock Filters determines which request should mock or not.
///
/// After mock not found MockingStar requests original request and returns to client at the same time Mock Decider makes a decision this request should be mocked or not mocked.
///
///
/// ```json
///{
///      "inputText" : "product",
///      "isActive" : true,
///      "selectedFilter" : "contains",
///      "selectedLocation" : "path"
///}
/// ```
/// Based on given config model, 
///
/// Any request that has `product` in path should not mock.
/// Also path, query, scenario, method and status code usable as a source and filterable with contains, not contains, starts with, end with, equal and not equal.
///
public final class MockFilterConfigModel: Codable, Equatable, Identifiable, Hashable {
    public var id: String = UUID().uuidString

    public var isActive: Bool
    public var selectedLocation: FilterType
    public var selectedFilter: FilterStyle
    public var inputText: String

    public init(isActive: Bool = true,
                selectedLocation: FilterType = .all,
                selectedFilter: FilterStyle = .contains,
                inputText: String) {
        self.isActive = isActive
        self.selectedLocation = selectedLocation
        self.selectedFilter = selectedFilter
        self.inputText = inputText
    }

    public static func == (lhs: MockFilterConfigModel, rhs: MockFilterConfigModel) -> Bool {
        lhs.isActive == rhs.isActive &&
        lhs.selectedLocation == rhs.selectedLocation &&
        lhs.selectedFilter == rhs.selectedFilter &&
        lhs.inputText == rhs.inputText
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(isActive)
        hasher.combine(selectedLocation)
        hasher.combine(selectedFilter)
        hasher.combine(inputText)
    }
}

public enum FilterType: String, Codable, CaseIterable {
    case all
    case path, query
    case scenario
    case method, statusCode

    public var title: String {
        switch self {
        case .all: "All"
        case .path: "Path"
        case .query: "Query"
        case .scenario: "Scenario"
        case .method: "Method"
        case .statusCode: "Status Code"
        }
    }
}

public enum FilterStyle: String, Codable, CaseIterable {
    case contains, notContains
    case startWith, endWith
    case equal, notEqual

    public var title: String {
        switch self {
        case .contains: "Contains"
        case .notContains: "Not Contains"
        case .startWith: "Starts With"
        case .endWith: "End With"
        case .equal: "Equal"
        case .notEqual: "Not Equal"
        }
    }
}

/// App Configs determines base settings about MockingStar
/// Common mock configurations.
///
/// ```json
/// {
///     "domains" : ["trendyol.com"],
///     "headerExecuteStyle" : "ignoreAll",
///     "queryExecuteStyle" : "matchAll",
///     "pathMatchingRatio" : 0.8
/// }
/// ```
public final class AppConfigModel: Codable, Equatable {
    public var queryExecuteStyle: QueryExecuteStyle
    public var headerExecuteStyle: HeaderExecuteStyle
    public var pathMatchingRatio: Double
    public var domains: [String]

    public init(queryExecuteStyle: QueryExecuteStyle = .ignoreAll,
                headerExecuteStyle: HeaderExecuteStyle = .ignoreAll,
                pathMatchingRatio: Double = 1,
                domains: [String] = []) {
        self.queryExecuteStyle = queryExecuteStyle
        self.headerExecuteStyle = headerExecuteStyle
        self.pathMatchingRatio = pathMatchingRatio
        self.domains = domains
    }

    public static func == (lhs: AppConfigModel, rhs: AppConfigModel) -> Bool {
        lhs.queryExecuteStyle == rhs.queryExecuteStyle &&
        lhs.headerExecuteStyle == rhs.headerExecuteStyle &&
        lhs.pathMatchingRatio == rhs.pathMatchingRatio &&
        lhs.domains == rhs.domains
    }
    
    private enum CodingKeys: CodingKey {
        case queryExecuteStyle
        case headerExecuteStyle
        case pathMatchingRatio
        case domains
    }

    private enum Migration_CodingKeys: CodingKey {
        case queryFilterDefaultStyleIgnore
        case headerFilterDefaultStyleIgnore
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AppConfigModel.CodingKeys.self)

        do {
            self.queryExecuteStyle = try container.decode(QueryExecuteStyle.self, forKey: AppConfigModel.CodingKeys.queryExecuteStyle)
        } catch {
            // Migrate queryFilterDefaultStyleIgnore to QueryExecuteStyle
            let container = try decoder.container(keyedBy: AppConfigModel.Migration_CodingKeys.self)
            let queryFilterDefaultStyleIgnore = try container.decode(Bool.self, forKey: AppConfigModel.Migration_CodingKeys.queryFilterDefaultStyleIgnore)
            self.queryExecuteStyle = queryFilterDefaultStyleIgnore ? .ignoreAll : .matchAll
        }

        do {
            self.headerExecuteStyle = try container.decode(HeaderExecuteStyle.self, forKey: AppConfigModel.CodingKeys.headerExecuteStyle)
        } catch {
            // Migrate headerFilterDefaultStyleIgnore to QueryExecuteStyle
            let container = try decoder.container(keyedBy: AppConfigModel.Migration_CodingKeys.self)
            let headerFilterDefaultStyleIgnore = try container.decode(Bool.self, forKey: AppConfigModel.Migration_CodingKeys.headerFilterDefaultStyleIgnore)
            self.headerExecuteStyle = headerFilterDefaultStyleIgnore ? .ignoreAll : .matchAll
        }
        self.pathMatchingRatio = try container.decode(Double.self, forKey: AppConfigModel.CodingKeys.pathMatchingRatio)
        self.domains = try container.decode([String].self, forKey: AppConfigModel.CodingKeys.domains)
    }
}

public enum QueryExecuteStyle: String, Codable, CaseIterable {
    case ignoreAll
    case matchAll

    public var title: String {
        switch self {
        case .ignoreAll: "Ignore All Query Items"
        case .matchAll: "Match All Query Items"
        }
    }
}

public enum HeaderExecuteStyle: String, Codable, CaseIterable {
    case ignoreAll
    case matchAll

    public var title: String {
        switch self {
        case .ignoreAll: "Ignore All Header Items"
        case .matchAll: "Match All Header Items"
        }
    }
}
