//
//  File.swift
//
//
//  Created by Yusuf Özgül on 5.12.2023.
//

import Combine
import CommonKit
import MockingStarCore

public final class MockMockDiscover: MockDiscoverInterface {
    public init() {}
    
    public var invokedMockListSubjectSetter = false
    public var invokedMockListSubjectSetterCount = 0
    public var invokedMockListSubject: CurrentValueSubject<Set<CommonKit.MockModel>?, Never>?
    public var invokedMockListSubjectList: [CurrentValueSubject<Set<CommonKit.MockModel>?, Never>] = []
    public var invokedMockListSubjectGetter = false
    public var invokedMockListSubjectGetterCount = 0
    public var stubbedMockListSubject: CurrentValueSubject<Set<CommonKit.MockModel>?, Never>!
    public var mockListSubject: CurrentValueSubject<Set<CommonKit.MockModel>?, Never> {
        set {
            invokedMockListSubjectSetter = true
            invokedMockListSubjectSetterCount += 1
            invokedMockListSubject = newValue
            invokedMockListSubjectList.append(newValue)
        }
        get {
            invokedMockListSubjectGetter = true
            invokedMockListSubjectGetterCount += 1
            return stubbedMockListSubject
        }
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
