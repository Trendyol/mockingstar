//
//  MockDomainConfigsUIModel.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 20.10.2023.
//

import CommonKit
import Foundation
import SwiftUI

@Observable
final class AppFilterConfigs: Equatable, Identifiable, Hashable {
    var id: UUID
    var queryExecuteStyle: QueryExecuteStyle
    var headerExecuteStyle: HeaderExecuteStyle
    var domains: [AppFilterConfigDomain]
    var pathMatchingRatio: Double

    init(queryExecuteStyle: QueryExecuteStyle = .ignoreAll,
         headerExecuteStyle: HeaderExecuteStyle = .ignoreAll,
         domains: [AppFilterConfigDomain] = [],
         pathMatchingRatio: Double = 1) {
        id = .init()
        self.queryExecuteStyle = queryExecuteStyle
        self.headerExecuteStyle = headerExecuteStyle
        self.domains = domains
        self.pathMatchingRatio = pathMatchingRatio
    }

    convenience init(appFilterConfigs: AppConfigModel) {
        self.init(queryExecuteStyle: appFilterConfigs.queryExecuteStyle,
                  headerExecuteStyle: appFilterConfigs.headerExecuteStyle,
                  domains: appFilterConfigs.domains.map { .init(domain: $0) },
                  pathMatchingRatio: appFilterConfigs.pathMatchingRatio)
    }

    func asAppConfigModel() -> AppConfigModel {
        AppConfigModel(queryExecuteStyle: queryExecuteStyle,
                       headerExecuteStyle: headerExecuteStyle,
                       pathMatchingRatio: pathMatchingRatio,
                       domains: domains.map(\.domain))
    }

    static func == (lhs: AppFilterConfigs, rhs: AppFilterConfigs) -> Bool {
        lhs.queryExecuteStyle == rhs.queryExecuteStyle &&
        lhs.headerExecuteStyle == rhs.headerExecuteStyle &&
        lhs.domains == rhs.domains &&
        lhs.pathMatchingRatio == rhs.pathMatchingRatio
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(queryExecuteStyle)
        hasher.combine(headerExecuteStyle)
        hasher.combine(domains)
        hasher.combine(pathMatchingRatio)
    }
}

@Observable
final class AppFilterConfigDomain: Equatable, Identifiable, Hashable {
    let id: UUID
    var domain: String

    init(domain: String) {
        self.id = .init()
        self.domain = domain
    }

    static func == (lhs: AppFilterConfigDomain, rhs: AppFilterConfigDomain) -> Bool {
        lhs.domain == rhs.domain
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(domain)
    }
}

@Observable
final class MockFilterConfigs: Equatable, Identifiable, Hashable {
    var id: UUID
    var selectedLocation: FilterType
    var selectedFilter: FilterStyle
    var inputText: String
    var logicType: FilterLogicType

    init(selectedLocation: FilterType = .all,
         selectedFilter: FilterStyle = .contains,
         inputText: String,
         logicType: FilterLogicType = .or) {
        id = .init()
        self.selectedLocation = selectedLocation
        self.selectedFilter = selectedFilter
        self.inputText = inputText
        self.logicType = logicType
    }

    convenience init(mockFilterConfig: MockFilterConfigModel) {
        self.init(selectedLocation: mockFilterConfig.selectedLocation,
                  selectedFilter: mockFilterConfig.selectedFilter,
                  inputText: mockFilterConfig.inputText,
                  logicType: mockFilterConfig.logicType)
    }

    func asMockFilterConfigModel() -> MockFilterConfigModel {
        MockFilterConfigModel(selectedLocation: selectedLocation,
                              selectedFilter: selectedFilter,
                              inputText: inputText,
                              logicType: logicType)
    }

    static func == (lhs: MockFilterConfigs, rhs: MockFilterConfigs) -> Bool {
        lhs.selectedLocation == rhs.selectedLocation &&
        lhs.selectedFilter == rhs.selectedFilter &&
        lhs.inputText == rhs.inputText &&
        lhs.logicType == rhs.logicType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(selectedLocation)
        hasher.combine(selectedFilter)
        hasher.combine(inputText)
        hasher.combine(logicType)
    }
}

@Observable
final class MockPathConfigModel: Codable, Equatable, Identifiable, Hashable {
    var id: UUID
    var path: String
    var queryExecuteStyle: QueryExecuteStyle
    var headerExecuteStyle: HeaderExecuteStyle

    init(path: String, queryExecuteStyle: QueryExecuteStyle, headerExecuteStyle: HeaderExecuteStyle) {
        id = .init()
        self.path = path
        self.queryExecuteStyle = queryExecuteStyle
        self.headerExecuteStyle = headerExecuteStyle
    }

    convenience init(pathConfig: PathConfigModel) {
        self.init(path: pathConfig.path,
                  queryExecuteStyle: pathConfig.queryExecuteStyle,
                  headerExecuteStyle: pathConfig.headerExecuteStyle)
    }

    func asPathConfigModel() -> PathConfigModel {
        PathConfigModel(path: path,
                        queryExecuteStyle: queryExecuteStyle,
                        headerExecuteStyle: headerExecuteStyle)
    }

    static func == (lhs: MockPathConfigModel, rhs: MockPathConfigModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.path == rhs.path &&
        lhs.queryExecuteStyle == rhs.queryExecuteStyle &&
        lhs.headerExecuteStyle == rhs.headerExecuteStyle
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(queryExecuteStyle)
        hasher.combine(headerExecuteStyle)
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _path = "path"
        case _queryExecuteStyle = "queryExecuteStyle"
        case _headerExecuteStyle = "headerExecuteStyle"
    }
}

@Observable
final class MockQueryConfigModel: Codable, Equatable, Identifiable, Hashable {
    var id: UUID
    var path: [String]
    var key: String
    var value: String

    init(path: [String] = [], key: String, value: String) {
        id = .init()
        self.path = path
        self.key = key
        self.value = value
    }

    convenience init(queryConfig: QueryConfigModel) {
        self.init(path: queryConfig.path,
                  key: queryConfig.key,
                  value: queryConfig.value ?? "")
    }

    func asQueryConfigModel() -> QueryConfigModel {
        QueryConfigModel(path: path,
                         key: key,
                         value: value)
    }

    static func == (lhs: MockQueryConfigModel, rhs: MockQueryConfigModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.path == rhs.path &&
        lhs.key == rhs.key &&
        lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(key)
        hasher.combine(value)
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _path = "path"
        case _key = "key"
        case _value = "value"
    }
}

@Observable
final class MockHeaderConfigModel: Codable, Equatable, Identifiable, Hashable {
    var id: UUID
    var path: [String]
    var key: String
    var value: String


    init(path: [String] = [], key: String, value: String) {
        id = .init()
        self.path = path
        self.key = key
        self.value = value
    }

    convenience init(headerConfig: HeaderConfigModel) {
        self.init(path: headerConfig.path,
                  key: headerConfig.key,
                  value: headerConfig.value ?? "")
    }

    func asHeaderConfigModel() -> HeaderConfigModel {
        HeaderConfigModel(path: path,
                          key: key,
                          value: value)
    }

    static func == (lhs: MockHeaderConfigModel, rhs: MockHeaderConfigModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.path == rhs.path &&
        lhs.key == rhs.key &&
        lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(key)
        hasher.combine(value)
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _path = "path"
        case _key = "key"
        case _value = "value"
    }
}
