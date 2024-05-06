//
//  MockLogStreamHandler.swift
//
//
//  Created by Yusuf Özgül on 6.05.2024.
//

import CommonKit
import Foundation

public final class MockLogStreamHandler: LogStreamHandlerInterface {
    public init() {}

    public var invokedReadAllLogs = false
    public var invokedReadAllLogsCount = 0
    public var stubbedReadAllLogsResult: [CommonKit.LogModel]!
    public func readAllLogs() -> [CommonKit.LogModel] {
        invokedReadAllLogs = true
        invokedReadAllLogsCount += 1
        return stubbedReadAllLogsResult
    }

    public var invokedStream = false
    public var invokedStreamCount = 0
    public var stubbedStreamResult: AsyncStream<CommonKit.LogModel>!
    public func stream() -> AsyncStream<CommonKit.LogModel> {
        invokedStream = true
        invokedStreamCount += 1
        return stubbedStreamResult
    }
}
