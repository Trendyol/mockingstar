//
//  JSONFileLogHandler.swift
//
//
//  Created by Yusuf Özgül on 4.05.2024.
//

import Foundation
import Logging

final class JSONFileLogHandler: LogHandler {
    static let shared = JSONFileLogHandler()
    private let fileURL: URL
    private let fileHandle: FileHandle?
    private let jsonEncoder = JSONEncoder()

    private init() {
        let fileURL = URL.cachesDirectory.appending(component: "logs.json")
        if FileManager.default.fileExists(atPath: fileURL.path()) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        FileManager.default.createFile(atPath: fileURL.path(), contents: nil)

        self.fileURL = fileURL
        self.fileHandle = try? FileHandle(forWritingTo: fileURL)
        self.fileHandle?.seekToEndOfFile()
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    }

    func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        let logModel = LogModel(severity: .severity(from: level),
                                message: "\(message)",
                                category: metadata?["category"]?.description ?? "")

        guard var data = try? jsonEncoder.encode(logModel) else { return }
        data.append(",\n".data(using: .utf8) ?? .init())
        fileHandle?.write(data)
    }
}
