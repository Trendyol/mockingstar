//
//  MockURLSession.swift
//
//
//  Created by Yusuf Özgül on 5.12.2023.
//

import CommonKit
import Foundation

public final class MockURLSession: URLSessionInterface {
    public init() {}

    public var invokedData = false
    public var invokedDataCount = 0
    public var invokedDataParameters: (request: URLRequest, Void)?
    public var invokedDataParametersList: [(request: URLRequest, Void)] = []
    public var stubbedDataResult: (Data, URLResponse)!
    public func data(for request: URLRequest) throws -> (Data, URLResponse) {
        invokedData = true
        invokedDataCount += 1
        invokedDataParameters = (request, ())
        invokedDataParametersList.append((request, ()))
        return stubbedDataResult
    }
}
