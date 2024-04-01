//
//  MockMockDiscover.swift
//
//
//  Created by Yusuf Özgül on 5.12.2023.
//

import CommonKit
import MockingStarCore

public final class MockMockDiscover: MockDiscoverInterface {
    public init() {}

    public var invokedMockDiscoverResultGetter = false
    public var invokedMockDiscoverResultGetterCount = 0
    public var stubbedMockDiscoverResult: AsyncStream<MockDiscoverResult>!

    public var mockDiscoverResult: AsyncStream<MockDiscoverResult> {
        invokedMockDiscoverResultGetter = true
        invokedMockDiscoverResultGetterCount += 1
        return stubbedMockDiscoverResult
    }

    public var invokedUpdateMockDomain = false
    public var invokedUpdateMockDomainCount = 0
    public var invokedUpdateMockDomainParameters: (mockDomain: String, Void)?
    public var invokedUpdateMockDomainParametersList: [(mockDomain: String, Void)] = []
    public func updateMockDomain(_ mockDomain: String) throws {
        invokedUpdateMockDomain = true
        invokedUpdateMockDomainCount += 1
        invokedUpdateMockDomainParameters = (mockDomain, ())
        invokedUpdateMockDomainParametersList.append((mockDomain, ()))
    }

    public var invokedReloadMocks = false
    public var invokedReloadMocksCount = 0
    public func reloadMocks() async throws {
        invokedReloadMocks = true
        invokedReloadMocksCount += 1
    }
}
