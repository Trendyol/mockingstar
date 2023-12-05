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
    var queryFilterDefaultStyleIgnore: Bool
    var headerFilterDefaultStyleIgnore: Bool
    var domains: [AppFilterConfigDomain]
    var pathMatchingRatio: Double

    init(queryFilterDefaultStyleIgnore: Bool = true,
         headerFilterDefaultStyleIgnore: Bool = true,
         domains: [AppFilterConfigDomain] = [],
         pathMatchingRatio: Double = 1) {
        id = .init()
        self.queryFilterDefaultStyleIgnore = queryFilterDefaultStyleIgnore
        self.headerFilterDefaultStyleIgnore = headerFilterDefaultStyleIgnore
        self.domains = domains
        self.pathMatchingRatio = pathMatchingRatio
    }

    convenience init(appFilterConfigs: AppConfigModel) {
        self.init(queryFilterDefaultStyleIgnore: appFilterConfigs.queryFilterDefaultStyleIgnore,
                  headerFilterDefaultStyleIgnore: appFilterConfigs.headerFilterDefaultStyleIgnore,
                  domains: appFilterConfigs.domains.map { .init(domain: $0) },
                  pathMatchingRatio: appFilterConfigs.pathMatchingRatio)
    }

    func asAppConfigModel() -> AppConfigModel {
        AppConfigModel(queryFilterDefaultStyleIgnore: queryFilterDefaultStyleIgnore,
                       headerFilterDefaultStyleIgnore: headerFilterDefaultStyleIgnore,
                       domains: domains.map(\.domain),
                       pathMatchingRatio: pathMatchingRatio)
    }

    static func == (lhs: AppFilterConfigs, rhs: AppFilterConfigs) -> Bool {
        lhs.queryFilterDefaultStyleIgnore == rhs.queryFilterDefaultStyleIgnore &&
        lhs.headerFilterDefaultStyleIgnore == rhs.headerFilterDefaultStyleIgnore &&
        lhs.domains == rhs.domains &&
        lhs.pathMatchingRatio == rhs.pathMatchingRatio
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(queryFilterDefaultStyleIgnore)
        hasher.combine(headerFilterDefaultStyleIgnore)
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
    var isActive: Bool
    var selectedLocation: FilterType
    var selectedFilter: FilterStyle
    var inputText: String

    init(isActive: Bool = true,
         selectedLocation: FilterType = .all,
         selectedFilter: FilterStyle = .contains,
         inputText: String) {
        id = .init()
        self.isActive = isActive
        self.selectedLocation = selectedLocation
        self.selectedFilter = selectedFilter
        self.inputText = inputText
    }

    convenience init(mockFilterConfig: MockFilterConfigModel) {
        self.init(isActive: mockFilterConfig.isActive,
                  selectedLocation: mockFilterConfig.selectedLocation,
                  selectedFilter: mockFilterConfig.selectedFilter,
                  inputText: mockFilterConfig.inputText)
    }

    func asMockFilterConfigModel() -> MockFilterConfigModel {
        MockFilterConfigModel(isActive: isActive,
                              selectedLocation: selectedLocation,
                              selectedFilter: selectedFilter,
                              inputText: inputText)
    }

    static func == (lhs: MockFilterConfigs, rhs: MockFilterConfigs) -> Bool {
        lhs.isActive == rhs.isActive &&
        lhs.selectedLocation == rhs.selectedLocation &&
        lhs.selectedFilter == rhs.selectedFilter &&
        lhs.inputText == rhs.inputText
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(isActive)
        hasher.combine(selectedLocation)
        hasher.combine(selectedFilter)
        hasher.combine(inputText)
    }
}

@Observable
final class MockPathConfigModel: Codable, Equatable, Identifiable, Hashable {
    var id: UUID
    var path: String
    var executeAllQueries: Bool
    var executeAllHeaders: Bool

    init(path: String, executeAllQueries: Bool, executeAllHeaders: Bool) {
        id = .init()
        self.path = path
        self.executeAllQueries = executeAllQueries
        self.executeAllHeaders = executeAllHeaders
    }

    convenience init(pathConfig: PathConfigModel) {
        self.init(path: pathConfig.path,
                  executeAllQueries: pathConfig.executeAllQueries,
                  executeAllHeaders: pathConfig.executeAllHeaders)
    }

    func asPathConfigModel() -> PathConfigModel {
        PathConfigModel(path: path,
                        executeAllQueries: executeAllQueries,
                        executeAllHeaders: executeAllHeaders)
    }

    static func == (lhs: MockPathConfigModel, rhs: MockPathConfigModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.path == rhs.path &&
        lhs.executeAllHeaders == rhs.executeAllHeaders &&
        lhs.executeAllQueries == rhs.executeAllQueries
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(executeAllQueries)
        hasher.combine(executeAllHeaders)
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _path = "path"
        case _executeAllHeaders = "executeAllHeaders"
        case _executeAllQueries = "executeAllQueries"
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
