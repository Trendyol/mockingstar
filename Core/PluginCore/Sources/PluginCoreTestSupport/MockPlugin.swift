//
//  MockPlugin.swift
//
//
//  Created by Yusuf Özgül on 4.12.2023.
//

import PluginCore
import CommonKit

public final class MockPlugin: PluginInterface {
    public init() {}

    public var invokedConfigAvailablePlugins = false
    public var invokedConfigAvailablePluginsCount = 0
    public var stubbedConfigAvailablePluginsResult: [PluginCore.ConfigurablePluginModel]!
    public func configAvailablePlugins() -> [PluginCore.ConfigurablePluginModel] {
        invokedConfigAvailablePlugins = true
        invokedConfigAvailablePluginsCount += 1
        return stubbedConfigAvailablePluginsResult
    }

    public var invokedRequestReloaderPlugin = false
    public var invokedRequestReloaderPluginCount = 0
    public var invokedRequestReloaderPluginParameters: (request: PluginCore.URLRequestModel, Void)?
    public var invokedRequestReloaderPluginParametersList: [(request: PluginCore.URLRequestModel, Void)] =  []
    public var stubbedRequestReloaderPluginResult: PluginCore.URLRequestModel!
    public func requestReloaderPlugin(request: PluginCore.URLRequestModel) throws -> PluginCore.URLRequestModel {
        invokedRequestReloaderPlugin = true
        invokedRequestReloaderPluginCount += 1
        invokedRequestReloaderPluginParameters = (request, ())
        invokedRequestReloaderPluginParametersList.append((request, ()))
        return stubbedRequestReloaderPluginResult
    }

    public var invokedLiveRequestPlugin = false
    public var invokedLiveRequestPluginCount = 0
    public var invokedLiveRequestPluginParameters: (request: PluginCore.URLRequestModel, Void)?
    public var invokedLiveRequestPluginParametersList: [(request: PluginCore.URLRequestModel, Void)] = []
    public var stubbedLiveRequestPluginResult: PluginCore.URLRequestModel!
    public func liveRequestPlugin(request: PluginCore.URLRequestModel) throws -> PluginCore.URLRequestModel {
        invokedLiveRequestPlugin = true
        invokedLiveRequestPluginCount += 1
        invokedLiveRequestPluginParameters = (request, ())
        invokedLiveRequestPluginParametersList.append((request, ()))
        return stubbedLiveRequestPluginResult
    }

    public var invokedMockErrorPlugin = false
    public var invokedMockErrorPluginCount = 0
    public var invokedMockErrorPluginParameters: (message: String, Void)?
    public var invokedMockErrorPluginParametersList: [(message: String, Void)] = []
    public var stubbedMockErrorPluginResult: String!
    public func mockErrorPlugin(message: String) throws -> String {
        invokedMockErrorPlugin = true
        invokedMockErrorPluginCount += 1
        invokedMockErrorPluginParameters = (message, ())
        invokedMockErrorPluginParametersList.append((message, ()))
        return stubbedMockErrorPluginResult
    }

    public var invokedMockDetailMessagePlugin = false
    public var invokedMockDetailMessagePluginCount = 0
    public var invokedMockDetailMessagePluginParameters: (mock: CommonKit.MockModel, Void)?
    public var invokedMockDetailMessagePluginParametersList: [(mock: CommonKit.MockModel, Void)] = []
    public var stubbedMockDetailMessagePluginResult: String!
    public func mockDetailMessagePlugin(mock: CommonKit.MockModel) throws -> String {
        invokedMockDetailMessagePlugin = true
        invokedMockDetailMessagePluginCount += 1
        invokedMockDetailMessagePluginParameters = (mock, ())
        invokedMockDetailMessagePluginParametersList.append((mock, ()))
        return stubbedMockDetailMessagePluginResult
    }

    public var invokedAsyncMockDetailMessagePlugin = false
    public var invokedAsyncMockDetailMessagePluginCount = 0
    public var invokedAsyncMockDetailMessagePluginParameters: (mock: CommonKit.MockModel, Void)?
    public var invokedAsyncMockDetailMessagePluginParametersList: [(mock: CommonKit.MockModel, Void)] = []
    public var stubbedAsyncMockDetailMessagePluginResult: String!
    public func asyncMockDetailMessagePlugin(mock: CommonKit.MockModel) throws -> String {
        invokedAsyncMockDetailMessagePlugin = true
        invokedAsyncMockDetailMessagePluginCount += 1
        invokedAsyncMockDetailMessagePluginParameters = (mock, ())
        invokedAsyncMockDetailMessagePluginParametersList.append((mock, ()))
        return stubbedAsyncMockDetailMessagePluginResult
    }
}
