//
//  OSLogHandler.swift
//
//
//  Created by Yusuf Özgül on 4.05.2024.
//

#if os(macOS)
import Foundation
import Logging
import OSLog

final class OSLogHandler: LogHandler {
    private let osLogger: os.Logger

    init(category: String) {
        osLogger = .init(subsystem: Logger.Constant.subsystem, category: category)
    }

    func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        switch level {
        case .trace:
            osLogger.trace("\(message)")
        case .debug:
            osLogger.debug("\(message)")
        case .info:
            osLogger.info("\(message)")
        case .notice:
            osLogger.notice("\(message)")
        case .warning:
            osLogger.warning("\(message)")
        case .error:
            osLogger.error("\(message)")
        case .critical:
            osLogger.critical("\(message)")
        }
    }
}

#endif
