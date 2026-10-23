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
    private let lock = NSLock()

    private init() {
        let fileURL: URL

        let customFolderExist = FileManager.default.fileOrDirectoryExists(atPath: Logger.Constant.customLogFolderPath)
        if customFolderExist.isExist && customFolderExist.isDirectory {
            fileURL = URL(filePath: Logger.Constant.customLogFolderPath).appending(path: "MockingStar.log")
            if !FileManager.default.fileExists(atPath: fileURL.path()) { FileManager.default.createFile(atPath: fileURL.path(), contents: nil) }
        } else if customFolderExist.isExist {
            fileURL = URL(filePath: Logger.Constant.customLogFolderPath)
        } else {
            fileURL = URL(filePath: Logger.Constant.customLogFolderPath)
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: fileURL.path(), contents: nil)
        }

        self.fileURL = fileURL
        self.fileHandle = try? FileHandle(forWritingTo: fileURL)
        self.fileHandle?.seekToEndOfFile()
    }

    func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        lock.lock(); defer { lock.unlock() }
        let metadata: [String:String] = (metadata?.map { ($0, $1.description)} ?? []).reduce(into: [:]) { $0[$1.0] = $1.1 }
        let log = LogModel(severity: .severity(from: level),
                           message: "\(message)",
                           category: metadata["category"] ?? "",
                           metadata: metadata)

        let details = metadata.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        let data = "\(log.date.formatted(.iso8601)) \(log.severity.rawValue) \(log.message) \(details)".data(using: .utf8) ?? .init()
        fileHandle?.write(data)
        fileHandle?.write("\n".data(using: .utf8) ?? .init())
    }
}
