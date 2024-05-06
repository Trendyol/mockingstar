//
//  ConsoleLogHandler.swift
//
//
//  Created by Yusuf Özgül on 4.05.2024.
//

import Foundation
import Logging

final class ConsoleLogHandler: LogHandler {
    func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        let log = LogModel(severity: .severity(from: level),
                           message: "\(message)",
                           category: metadata?["category"]?.description ?? "")

        print("\(log.date.formatted(.iso8601)) \(log.severity.rawValue) \(log.message)")
    }
}
