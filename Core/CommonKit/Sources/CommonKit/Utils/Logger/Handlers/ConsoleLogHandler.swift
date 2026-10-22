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
        let metadataValues: [String: String] = (metadata?.map { ($0, $1.description) } ?? []).reduce(into: [:]) { $0[$1.0] = $1.1 }
        let log = LogModel(severity: .severity(from: level),
                           message: "\(message)",
                           category: metadataValues["category"] ?? "")

        var output = "\(log.date.formatted(.iso8601)) \(log.severity.rawValue) \(log.message)"
        if log.message == "Mock Trace" {
            let extras = ["method", "responseType", "duration", "traceUrl", "errorMessage"]
                .compactMap { key in metadataValues[key].map { "\(key)=\($0)" } }
                .joined(separator: " ")
            if !extras.isEmpty {
                output += " \(extras)"
            }
        }
        print(output)
    }
}
