//
//  MockPluginCoreActor.swift
//
//
//  Created by Yusuf Özgül on 4.12.2023.
//

import Foundation
import PluginCore

public final class MockPluginCoreActor: PluginCoreActorInterface {
    public init() {}

    public var invokedPluginCore = false
    public var invokedPluginCoreCount = 0
    public var invokedPluginCoreParameters: (mockDomain: String, Void)?
    public var invokedPluginCoreParametersList: [(mockDomain: String, Void)] = []
    public var stubbedPluginCoreResult: PluginCore.PluginInterface!
    public func pluginCore(for mockDomain: String) -> PluginInterface {
        invokedPluginCore = true
        invokedPluginCoreCount += 1
        invokedPluginCoreParameters = (mockDomain, ())
        invokedPluginCoreParametersList.append((mockDomain, ()))
        return stubbedPluginCoreResult
    }

}

