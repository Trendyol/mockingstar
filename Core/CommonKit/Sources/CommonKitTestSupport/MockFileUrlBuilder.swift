//
//  MockFileUrlBuilder.swift
//
//
//  Created by Yusuf Özgül on 2.09.2023.
//

import Foundation

@testable import CommonKit

public final class MockFileUrlBuilder: FileUrlBuilderInterface {
    public init() { }

    public var invokedDomainsFolderUrl = false
    public var invokedDomainsFolderUrlCount = 0
    public var stubbedDomainsFolderUrlResult: URL!
    public func domainsFolderUrl() throws -> URL {
        invokedDomainsFolderUrl = true
        invokedDomainsFolderUrlCount += 1
        return stubbedDomainsFolderUrlResult
    }

    public var invokedDomainFolder = false
    public var invokedDomainFolderCount = 0
    public var invokedDomainFolderParameters: (mockDomain: String, Void)?
    public var invokedDomainFolderParametersList: [(mockDomain: String, Void)] = []
    public var stubbedDomainFolderResult: URL!
    public func domainFolder(for mockDomain: String) throws -> URL {
        invokedDomainFolder = true
        invokedDomainFolderCount += 1
        invokedDomainFolderParameters = (mockDomain, ())
        invokedDomainFolderParametersList.append((mockDomain, ()))
        return stubbedDomainFolderResult
    }

    public var invokedMocksFolderUrl = false
    public var invokedMocksFolderUrlCount = 0
    public var invokedMocksFolderUrlParameters: (mockDomain: String, Void)?
    public var invokedMocksFolderUrlParametersList: [(mockDomain: String, Void)] = []
    public var stubbedMocksFolderUrlResult: URL!
    public func mocksFolderUrl(for mockDomain: String) throws -> URL {
        invokedMocksFolderUrl = true
        invokedMocksFolderUrlCount += 1
        invokedMocksFolderUrlParameters = (mockDomain, ())
        invokedMocksFolderUrlParametersList.append((mockDomain, ()))
        return stubbedMocksFolderUrlResult
    }

    public var invokedMockListFolderUrl = false
    public var invokedMockListFolderUrlCount = 0
    public var invokedMockListFolderUrlParameters: (mocksFolderURL: URL, requestPath: String, method: String, Void)?
    public var invokedMockListFolderUrlParametersList: [(mocksFolderURL: URL, requestPath: String, method: String, Void)] = []
    public var stubbedMockListFolderUrlResult: URL!
    public func mockListFolderUrl(mocksFolderURL: URL, requestPath: String, method: String) -> URL {
        invokedMockListFolderUrl = true
        invokedMockListFolderUrlCount += 1
        invokedMockListFolderUrlParameters = (mocksFolderURL, requestPath, method, ())
        invokedMockListFolderUrlParametersList.append((mocksFolderURL, requestPath, method, ()))
        return stubbedMockListFolderUrlResult
    }

    public var invokedMockListConfiguredUrl = false
    public var invokedMockListConfiguredUrlCount = 0
    public var invokedMockListConfiguredUrlParameters: (mocksFolderURL: URL, requestPath: String, configPath: String, method: String, Void)?
    public var invokedMockListConfiguredUrlParametersList: [(mocksFolderURL: URL, requestPath: String, configPath: String, method: String, Void)] = []
    public var stubbedMockListConfiguredUrlResult: URL!
    public  func mockListConfiguredUrl(mocksFolderURL: URL, requestPath: String, configPath: String, method: String) throws -> URL {
        invokedMockListConfiguredUrl = true
        invokedMockListConfiguredUrlCount += 1
        invokedMockListConfiguredUrlParameters = (mocksFolderURL, requestPath, configPath, method, ())
        invokedMockListConfiguredUrlParametersList.append((mocksFolderURL, requestPath, configPath, method, ()))
        return stubbedMockListConfiguredUrlResult
    }

    public var invokedConfigsFolderUrl = false
    public var invokedConfigsFolderUrlCount = 0
    public var invokedConfigsFolderUrlParameters: (mockDomain: String, Void)?
    public var invokedConfigsFolderUrlParametersList: [(mockDomain: String, Void)] = []
    public var stubbedConfigsFolderUrlResult: URL!
    public func configsFolderUrl(for mockDomain: String) throws -> URL {
        invokedConfigsFolderUrl = true
        invokedConfigsFolderUrlCount += 1
        invokedConfigsFolderUrlParameters = (mockDomain, ())
        invokedConfigsFolderUrlParametersList.append((mockDomain, ()))
        return stubbedConfigsFolderUrlResult
    }

    public var invokedConfigUrl = false
    public var invokedConfigUrlCount = 0
    public var invokedConfigUrlParameters: (mockDomain: String, Void)?
    public var invokedConfigUrlParametersList: [(mockDomain: String, Void)] = []
    public var stubbedConfigUrlResult: URL!
    public func configUrl(for mockDomain: String) throws -> URL {
        invokedConfigUrl = true
        invokedConfigUrlCount += 1
        invokedConfigUrlParameters = (mockDomain, ())
        invokedConfigUrlParametersList.append((mockDomain, ()))
        return stubbedConfigUrlResult
    }

    public var invokedPluginFolderUrl = false
    public var invokedPluginFolderUrlCount = 0
    public var invokedPluginFolderUrlParameters: (mockDomain: String, Void)?
    public var invokedPluginFolderUrlParametersList: [(mockDomain: String, Void)] = []
    public var stubbedPluginFolderUrlResult: URL!
    public func pluginFolderUrl(for mockDomain: String) throws -> URL {
        invokedPluginFolderUrl = true
        invokedPluginFolderUrlCount += 1
        invokedPluginFolderUrlParameters = (mockDomain, ())
        invokedPluginFolderUrlParametersList.append((mockDomain, ()))
        return stubbedPluginFolderUrlResult
    }

    public var invokedCommonPluginFolderUrl = false
    public var invokedCommonPluginFolderUrlCount = 0
    public var stubbedCommonPluginFolderUrlResult: URL!
    public func commonPluginFolderUrl() throws -> URL {
        invokedCommonPluginFolderUrl = true
        invokedCommonPluginFolderUrlCount += 1
        return stubbedCommonPluginFolderUrlResult
    }

    public var invokedIsPathMatched = false
    public var invokedIsPathMatchedCount = 0
    public var invokedIsPathMatchedParameters:
        (requestPath: String, configPath: String, pathMatchingRatio: Double, Void)?
    public var invokedIsPathMatchedParametersList:
        [(requestPath: String, configPath: String, pathMatchingRatio: Double, Void)] = []
    public var stubbedIsPathMatchedResult: Bool!
    public func isPathMatched(requestPath: String, configPath: String, pathMatchingRatio: Double) -> Bool {
        invokedIsPathMatched = true
        invokedIsPathMatchedCount += 1
        invokedIsPathMatchedParameters = (requestPath, configPath, pathMatchingRatio, ())
        invokedIsPathMatchedParametersList.append((requestPath, configPath, pathMatchingRatio, ()))
        return stubbedIsPathMatchedResult
    }

}

