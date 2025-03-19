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
    public var invokedFindProperPathConfigsParameters: (mockUrl: URL, pathConfigs: [PathConfigModel], pathMatchingRatio: Double, Void)?
    public var invokedFindProperPathConfigsParametersList: [(mockUrl: URL, pathConfigs: [PathConfigModel], pathMatchingRatio: Double, Void)] = []
    public var stubbedFindProperPathConfigsResult: [PathConfigModel]!
    public func findProperPathConfigs(
        mockUrl: URL, pathConfigs: [PathConfigModel], pathMatchingRatio: Double
    ) -> [PathConfigModel] {
        invokedFindProperPathConfigs = true
        invokedFindProperPathConfigsCount += 1
        invokedFindProperPathConfigsParameters = (mockUrl, pathConfigs, pathMatchingRatio, ())
        invokedFindProperPathConfigsParametersList.append(
            (mockUrl, pathConfigs, pathMatchingRatio, ()))
        return stubbedFindProperPathConfigsResult
    }

    public var invokedFindProperQueryConfigs = false
    public var invokedFindProperQueryConfigsCount = 0
    public var invokedFindProperQueryConfigsParameters: (mockUrl: URL, queryConfigs: [QueryConfigModel], appFilterConfigs: AppConfigModel, Void)?
    public var invokedFindProperQueryConfigsParametersList: [(mockUrl: URL, queryConfigs: [QueryConfigModel], appFilterConfigs: AppConfigModel, Void)] = []
    public var stubbedFindProperQueryConfigsResult: [QueryConfigModel]!
    public func findProperQueryConfigs(mockUrl: URL, queryConfigs: [QueryConfigModel], appFilterConfigs: AppConfigModel) -> [QueryConfigModel] {
        invokedFindProperQueryConfigs = true
        invokedFindProperQueryConfigsCount += 1
        invokedFindProperQueryConfigsParameters = (mockUrl, queryConfigs, appFilterConfigs, ())
        invokedFindProperQueryConfigsParametersList.append(
            (mockUrl, queryConfigs, appFilterConfigs, ()))
        return stubbedFindProperQueryConfigsResult
    }

    public var invokedFindProperHeaderConfigs = false
    public var invokedFindProperHeaderConfigsCount = 0
    public var invokedFindProperHeaderConfigsParameters: (mockUrl: URL, headers: [String: String], headerConfigs: [HeaderConfigModel], appFilterConfigs: AppConfigModel, Void)?
    public var invokedFindProperHeaderConfigsParametersList: [( mockUrl: URL, headers: [String: String], headerConfigs: [HeaderConfigModel], appFilterConfigs: AppConfigModel, Void)] = []
    public var stubbedFindProperHeaderConfigsResult: [HeaderConfigModel]!
    public func findProperHeaderConfigs(mockUrl: URL, headers: [String: String], headerConfigs: [HeaderConfigModel], appFilterConfigs: AppConfigModel) -> [HeaderConfigModel] {
        invokedFindProperHeaderConfigs = true
        invokedFindProperHeaderConfigsCount += 1
        invokedFindProperHeaderConfigsParameters = (
            mockUrl, headers, headerConfigs, appFilterConfigs, ()
        )
        invokedFindProperHeaderConfigsParametersList.append(
            (mockUrl, headers, headerConfigs, appFilterConfigs, ()))
        return stubbedFindProperHeaderConfigsResult
    }
}
