//
//  File.swift
//
//
//  Created by Yusuf Özgül on 2.09.2023.
//

import Foundation
@testable import CommonKit

public final class MockConfigsBuilder: ConfigsBuilderInterface {
    public init() {}

    public var invokedFindProperPathConfigs = false
    public var invokedFindProperPathConfigsCount = 0
    public var invokedFindProperPathConfigsParameters: (mockUrl: URL, pathConfigs: [CommonKit.PathConfigModel], pathMatchingRatio: Double, Void)?
    public var invokedFindProperPathConfigsParametersList: [(mockUrl: URL, pathConfigs: [CommonKit.PathConfigModel], pathMatchingRatio: Double, Void)] = []
    public var stubbedFindProperPathConfigsResult: [CommonKit.PathConfigModel]!
    public func findProperPathConfigs(
        mockUrl: URL, pathConfigs: [CommonKit.PathConfigModel], pathMatchingRatio: Double
    ) -> [CommonKit.PathConfigModel] {
        invokedFindProperPathConfigs = true
        invokedFindProperPathConfigsCount += 1
        invokedFindProperPathConfigsParameters = (mockUrl, pathConfigs, pathMatchingRatio, ())
        invokedFindProperPathConfigsParametersList.append(
            (mockUrl, pathConfigs, pathMatchingRatio, ()))
        return stubbedFindProperPathConfigsResult
    }

    public var invokedFindProperQueryConfigs = false
    public var invokedFindProperQueryConfigsCount = 0
    public var invokedFindProperQueryConfigsParameters: (mockUrl: URL, queryConfigs: [CommonKit.QueryConfigModel], pathMatchingRatio: Double, Void)?
    public var invokedFindProperQueryConfigsParametersList: [(mockUrl: URL, queryConfigs: [CommonKit.QueryConfigModel], pathMatchingRatio: Double, Void)] = []
    public var stubbedFindProperQueryConfigsResult: [CommonKit.QueryConfigModel]!
    public func findProperQueryConfigs(mockUrl: URL, queryConfigs: [CommonKit.QueryConfigModel], pathMatchingRatio: Double) -> [CommonKit.QueryConfigModel] {
        invokedFindProperQueryConfigs = true
        invokedFindProperQueryConfigsCount += 1
        invokedFindProperQueryConfigsParameters = (mockUrl, queryConfigs, pathMatchingRatio, ())
        invokedFindProperQueryConfigsParametersList.append(
            (mockUrl, queryConfigs, pathMatchingRatio, ()))
        return stubbedFindProperQueryConfigsResult
    }

    public var invokedFindProperHeaderConfigs = false
    public var invokedFindProperHeaderConfigsCount = 0
    public var invokedFindProperHeaderConfigsParameters: (mockUrl: URL, headers: [String: String], headerConfigs: [CommonKit.HeaderConfigModel], pathMatchingRatio: Double, Void)?
    public var invokedFindProperHeaderConfigsParametersList: [( mockUrl: URL, headers: [String: String], headerConfigs: [CommonKit.HeaderConfigModel], pathMatchingRatio: Double, Void)] = []
    public var stubbedFindProperHeaderConfigsResult: [CommonKit.HeaderConfigModel]!
    public func findProperHeaderConfigs(mockUrl: URL, headers: [String: String], headerConfigs: [CommonKit.HeaderConfigModel], pathMatchingRatio: Double) -> [CommonKit.HeaderConfigModel] {
        invokedFindProperHeaderConfigs = true
        invokedFindProperHeaderConfigsCount += 1
        invokedFindProperHeaderConfigsParameters = (
            mockUrl, headers, headerConfigs, pathMatchingRatio, ()
        )
        invokedFindProperHeaderConfigsParametersList.append(
            (mockUrl, headers, headerConfigs, pathMatchingRatio, ()))
        return stubbedFindProperHeaderConfigsResult
    }
}
