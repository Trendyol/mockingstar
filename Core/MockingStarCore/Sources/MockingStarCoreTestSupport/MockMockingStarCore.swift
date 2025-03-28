//
//  MockMockingStarCore.swift
//  MockingStarCore
//
//  Created by Yusuf Özgül on 28.03.2025.
//

import CommonKit
import Foundation
import MockingStarCore

public final class MockMockingStarCore: MockingStarCoreInterface {
    public init() {}

    public var invokedImportMock = false
    public var invokedImportMockCount = 0
    public var invokedImportMockParametersList = [(url: URL, method: String, headers: [String: String], body: Data?, flags: MockServerFlags)]()
    public var stubbedImportMockResult: MockImportResult = .mocked

    public func importMock(url: URL, method: String, headers: [String: String], body: Data?, flags: MockServerFlags) async throws -> MockImportResult {
    invokedImportMock = true
    invokedImportMockCount += 1
    invokedImportMockParametersList.append((url: url, method: method, headers: headers, body: body, flags: flags))
    return stubbedImportMockResult

    }
}
