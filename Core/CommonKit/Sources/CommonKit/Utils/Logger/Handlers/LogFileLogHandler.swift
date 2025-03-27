//
//  LogFileLogHandler.swift
//
//
//  Created by Yusuf Özgül on 4.05.2024.
//

import Foundation
import Logging

final class LogFileLogHandler: LogHandler {
    static let shared = LogFileLogHandler()
    private let fileURL: URL
    private let fileHandle: FileHandle?

    private init() {
        let fileURL = URL(filePath: Logger.Constant.logsWriteFilePath)
        if FileManager.default.fileExists(atPath: fileURL.path()) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        FileManager.default.createFile(atPath: fileURL.path(), contents: nil)

        self.fileURL = fileURL
        self.fileHandle = try? FileHandle(forWritingTo: fileURL)
        self.fileHandle?.seekToEndOfFile()
    }

    func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        let metadata: [String:String] = (metadata?.map { ($0, $1.description)} ?? []).reduce(into: [:]) { $0[$1.0] = $1.1 }
        let log = LogModel(severity: .severity(from: level),
                           message: "\(message)",
                           category: metadata["category"] ?? "",
                           metadata: metadata)

        let data = "\(log.date.formatted(.iso8601)) \(log.severity.rawValue) \(log.message)".data(using: .utf8) ?? .init()
        fileHandle?.write(data)
    }
}
