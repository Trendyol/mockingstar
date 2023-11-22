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
///     "executeAllHeaders" : false,
///     "executeAllQueries" : true,
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
///     "executeAllHeaders" : false,
///     "executeAllQueries" : true,
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
    public var id: String { path + executeAllHeaders.description + executeAllQueries.description }

    public var path: String
    public var executeAllQueries: Bool
    public var executeAllHeaders: Bool

    public init(path: String, executeAllQueries: Bool, executeAllHeaders: Bool) {
        self.path = path
        self.executeAllQueries = executeAllQueries
        self.executeAllHeaders = executeAllHeaders
    }

    public static func == (lhs: PathConfigModel, rhs: PathConfigModel) -> Bool {
        lhs.path == rhs.path &&
        lhs.executeAllHeaders == rhs.executeAllHeaders &&
        lhs.executeAllQueries == rhs.executeAllQueries
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(executeAllQueries)
        hasher.combine(executeAllHeaders)
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
public final class AppConfigModel: Codable, Equatable {
    public var queryFilterDefaultStyleIgnore: Bool
    public var headerFilterDefaultStyleIgnore: Bool
    public var domains: [String]
    public var pathMatchingRatio: Double

    public init(queryFilterDefaultStyleIgnore: Bool = true,
                headerFilterDefaultStyleIgnore: Bool = true,
                domains: [String] = [],
                pathMatchingRatio: Double = 1) {
        self.queryFilterDefaultStyleIgnore = queryFilterDefaultStyleIgnore
        self.headerFilterDefaultStyleIgnore = headerFilterDefaultStyleIgnore
        self.domains = domains
        self.pathMatchingRatio = pathMatchingRatio
    }

    public static func == (lhs: AppConfigModel, rhs: AppConfigModel) -> Bool {
        lhs.queryFilterDefaultStyleIgnore == rhs.queryFilterDefaultStyleIgnore &&
        lhs.headerFilterDefaultStyleIgnore == rhs.headerFilterDefaultStyleIgnore &&
        lhs.domains == rhs.domains &&
        lhs.pathMatchingRatio == rhs.pathMatchingRatio
    }
}
