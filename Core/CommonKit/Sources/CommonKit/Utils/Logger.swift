//
//  File.swift
//
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import FlyingSocks
import Foundation
#if canImport(os)
@preconcurrency import os
#endif

public final class LogStorage {
    public static let shared = LogStorage()
    private var logs: [LogModel] = []
    private let (logStream, logContinuation) = AsyncStream.makeStream(of: LogModel.self)
    public let allLogsStream: AsyncStream<[LogModel]>
    private let allLogsContinuation: AsyncStream<[LogModel]>.Continuation

    private init() {
       (allLogsStream, allLogsContinuation) = AsyncStream.makeStream(of: [LogModel].self)

        Task {
            for await log in logStream {
                logs.append(log)
                allLogsContinuation.yield(logs)
            }
        }
    }

    fileprivate static func addLog(_ log: LogModel) {
        LogStorage.shared.logContinuation.yield(log)
    }

    public func writeToFile(_ folder: String) {
        guard let filePath = URL(string: folder)?.appending(path: "MockingStar.logs") else { return }
        if !FileManager.default.fileExists(atPath: filePath.path()) {
            FileManager.default.createFile(atPath: filePath.path(), contents: nil)
        }

        guard let fileHandle = try? FileHandle(forWritingTo: filePath) else { return }

        Task {
            for await log in logStream {
                let data = "\(log.date.formatted(.iso8601)) \(log.severity.rawValue) \(log.message)".data(using: .utf8) ?? .init()

                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
            }
        }
    }

    public func stdOut() {
        Task {
            for await log in logStream {
                print("\(log.date.formatted(.iso8601)) \(log.severity.rawValue) \(log.message)")
            }
        }
    }
}

public enum LogSeverity: String, CaseIterable {
    case debug, info, notice, warning, error, critical, fault
}

public struct LogModel: Hashable {
    public let severity: LogSeverity
    public let message: String
    public let date: Date
    public let category: String

    public init(severity: LogSeverity, message: String, category: String) {
        self.severity = severity
        self.message = message
        self.date = .init()
        self.category = category
    }
}

public final class Logger {
    private let logger: os.Logger
    private let category: String

    public init(category: String) {
        self.category = category
        logger = .init(subsystem: "com.trendyol.MockingStar", category: category)
    }

    public func debug(_ message: String) {
        logger.debug("\(message)")
        LogStorage.addLog(.init(severity: .debug,
                                message: message,
                                category: category))
    }

    public  func info(_ message: String) {
        logger.info("\(message)")
        LogStorage.addLog(.init(severity: .info,
                                message: message,
                                category: category))
    }

    public func notice(_ message: String) {
        logger.notice("\(message)")
        LogStorage.addLog(.init(severity: .critical,
                                message: message,
                                category: category))
    }

    public func warning(_ message: String) {
        logger.warning("\(message)")
        LogStorage.addLog(.init(severity: .warning,
                                message: message,
                                category: category))
    }

    public func error(_ message: String) {
        logger.error("\(message)")
        LogStorage.addLog(.init(severity: .error,
                                message: message,
                                category: category))
    }

    public func critical(_ message: String) {
        logger.critical("\(message)")
        LogStorage.addLog(.init(severity: .critical,
                                message: message,
                                category: category))
    }

    public func fault(_ message: String) {
        logger.fault("\(message)")
        LogStorage.addLog(.init(severity: .fault,
                                message: message,
                                category: category))
    }
}

public final class ServerLogger: Logging {
    private let logger: os.Logger
    private let category: String

    public init() {
        category = "Server"
        logger = .init(subsystem: "com.trendyol.MockingStar", category: "Server")
    }

    public func logDebug(_ debug: String) {
        logger.debug("\(debug)")
        LogStorage.addLog(.init(severity: .debug,
                                message: debug,
                                category: category))
    }

    public func logInfo(_ info: String) {
        guard !info.contains("open connection") && !info.contains("close connection") else { return }
        logger.debug("\(info)")
        LogStorage.addLog(.init(severity: .info,
                                message: info,
                                category: category))
    }

    public func logWarning(_ warning: String) {
        logger.debug("\(warning)")
        LogStorage.addLog(.init(severity: .warning,
                                message: warning,
                                category: category))
    }

    public func logError(_ error: String) {
        logger.debug("\(error)")
        LogStorage.addLog(.init(severity: .error,
                                message: error,
                                category: category))
    }

    public func logCritical(_ critical: String) {
        logger.debug("\(critical)")
        LogStorage.addLog(.init(severity: .critical,
                                message: critical,
                                category: category))
    }
}
