//
//  File.swift
//
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import Foundation
import Logging

extension Logger {
    public enum Constant {
        static let subsystem = "com.trendyol.MockingStar"
        public static var customLogFolderPath: String = ""
    }
}

public enum LogSeverity: String, CaseIterable, Codable {
    case debug, info, notice, warning, error, critical, fault

    static func severity(from level: Logging.Logger.Level) -> LogSeverity {
        return switch level {
        case .debug: .debug
        case .info: .info
        case .notice: .notice
        case .error: .error
        case .trace: .debug
        case .warning: .warning
        case .critical: .critical
        }
    }
}

public struct LogModel: Hashable, Identifiable, Codable {
    public var id: UUID
    public let severity: LogSeverity
    public let message: String
    public let date: Date
    public let category: String
    public let metadata: [String:String]

    public init(id: UUID = UUID(), severity: LogSeverity, message: String, category: String, metadata: [String:String] = [:], date: Date = .init()) {
        self.id = id
        self.severity = severity
        self.message = message
        self.date = date
        self.category = category
        self.metadata = metadata
    }
}

public final class Logger {
    private var logger: Logging.Logger
    private let category: String

    public init(category: String) {
        self.category = category
        logger = .init(label: category, factory: { label in
            var logHandlers: [LogHandler] = []

#if os(macOS)
            logHandlers.append(JSONFileLogHandler.shared)
            logHandlers.append(LogStreamHandler.shared)

#if DEBUG
            logHandlers.append(OSLogHandler(category: category))
#endif
#else
            logHandlers.append(ConsoleLogHandler())
#endif

            if !Constant.customLogFolderPath.isEmpty {
                logHandlers.append(LogFileLogHandler.shared)
            }

            return MultiplexLogHandler(logHandlers)
        })
        logger[metadataKey: "subsystem"] = .init(stringLiteral: Logger.Constant.subsystem)
    }

    public func debug(_ message: String, metadata: Logging.Logger.Metadata? = nil, file: String = #fileID, function: String = #function, line: UInt = #line) {
        logger.debug("\(message)", metadata: ["category": .init(stringLiteral: category)].merging(metadata ?? [:], uniquingKeysWith: {_, new in new }), file: file, function: function, line: line)
    }

    public  func info(_ message: String, metadata: Logging.Logger.Metadata? = nil, file: String = #fileID, function: String = #function, line: UInt = #line) {
        logger.info("\(message)", metadata: ["category": .init(stringLiteral: category)].merging(metadata ?? [:], uniquingKeysWith: {_, new in new }), file: file, function: function, line: line)
    }

    public func notice(_ message: String, metadata: Logging.Logger.Metadata? = nil, file: String = #fileID, function: String = #function, line: UInt = #line) {
        logger.notice("\(message)", metadata: ["category": .init(stringLiteral: category)].merging(metadata ?? [:], uniquingKeysWith: {_, new in new }), file: file, function: function, line: line)
    }

    public func warning(_ message: String, metadata: Logging.Logger.Metadata? = nil, file: String = #fileID, function: String = #function, line: UInt = #line) {
        logger.warning("\(message)", metadata: ["category": .init(stringLiteral: category)].merging(metadata ?? [:], uniquingKeysWith: {_, new in new }), file: file, function: function, line: line)
    }

    public func error(_ message: String, metadata: Logging.Logger.Metadata? = nil, file: String = #fileID, function: String = #function, line: UInt = #line) {
        logger.error("\(message)", metadata: ["category": .init(stringLiteral: category)].merging(metadata ?? [:], uniquingKeysWith: {_, new in new }), file: file, function: function, line: line)
    }

    public func critical(_ message: String, metadata: Logging.Logger.Metadata? = nil, file: String = #fileID, function: String = #function, line: UInt = #line) {
        logger.critical("\(message)", metadata: ["category": .init(stringLiteral: category)].merging(metadata ?? [:], uniquingKeysWith: {_, new in new }), file: file, function: function, line: line)
    }

    public func fault(_ message: String, metadata: Logging.Logger.Metadata? = nil, file: String = #fileID, function: String = #function, line: UInt = #line) {
        logger.critical("\(message)", metadata: ["category": .init(stringLiteral: category)].merging(metadata ?? [:], uniquingKeysWith: {_, new in new }), file: file, function: function, line: line)
    }
}
