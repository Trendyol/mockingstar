//
//  LogStreamHandler.swift
//
//
//  Created by Yusuf Özgül on 4.05.2024.
//

import Foundation
import Logging

public protocol LogStreamHandlerInterface {
    func readAllLogs() -> [LogModel]
    func stream() -> AsyncStream<LogModel>
}

public final class LogStreamHandler: LogHandler, LogStreamHandlerInterface {
    public static let shared = LogStreamHandler()
    var category: String = ""
    private var logContinuation: AsyncStream<LogModel>.Continuation?
    private let fileURL: URL
    private let jsonDecoder = JSONDecoder()

    private init() {
        fileURL = URL.cachesDirectory.appending(component: "logs.json")
    }

    public func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        let logModel = LogModel(severity: .severity(from: level),
                                message: "\(message)",
                                category: category)
        logContinuation?.yield(logModel)
    }

    public func readAllLogs() -> [LogModel] {
        var fileContent = (try? FileManager.default.readFile(at: fileURL)) ?? ""
        if !fileContent.isEmpty {
            fileContent.removeLast(2)
        }
        let data = ("["+fileContent+"]").data(using: .utf8) ?? .init()

        return (try? jsonDecoder.decode([LogModel].self, from: data)) ?? []
    }

    public func stream() -> AsyncStream<LogModel> {
        let (logStream, logContinuation) = AsyncStream.makeStream(of: LogModel.self)
        self.logContinuation = logContinuation
        return logStream
    }
}
