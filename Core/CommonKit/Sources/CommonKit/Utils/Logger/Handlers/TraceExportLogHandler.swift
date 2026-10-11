//
//  TraceExportLogHandler.swift
//
//
//  Created by Maide Başak Karahan on 4.10.2026.
//

import Foundation
import Logging

final class TraceExportLogHandler: LogHandler {
    static let shared = TraceExportLogHandler()
    private let fileHandle: FileHandle?
    private let jsonEncoder = JSONEncoder()

    init(fileManager: FileManagerInterface = FileManager.default) {
        let fileURL: URL
        let exportPath = Logger.Constant.traceExportPath
        let pathExists = fileManager.fileOrDirectoryExists(atPath: exportPath)

        if pathExists.isExist && pathExists.isDirectory {
            fileURL = URL(filePath: exportPath).appending(path: "MockingStarTrace.json")
            fileManager.createFile(atPath: fileURL.path(), contents: nil)
        } else if pathExists.isExist {
            fileURL = URL(filePath: exportPath)
            try? fileManager.removeFile(at: fileURL.path())
            fileManager.createFile(atPath: fileURL.path(), contents: nil)
        } else {
            fileURL = URL(filePath: exportPath)
            let directory = fileURL.deletingLastPathComponent()
            if !fileManager.fileOrDirectoryExists(atPath: directory.path()).isExist {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
            fileManager.createFile(atPath: fileURL.path(), contents: nil)
        }

        self.fileHandle = try? FileHandle(forWritingTo: fileURL)
        self.fileHandle?.seekToEndOfFile()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    }

    func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        guard "\(message)" == "Mock Trace" else { return }

        let metadata: [String: String] = (metadata?.map { ($0, $1.description) } ?? []).reduce(into: [:]) { $0[$1.0] = $1.1 }
        let log = LogModel(severity: .severity(from: level),
                           message: "\(message)",
                           category: metadata["category"] ?? "",
                           metadata: metadata)

        guard var data = try? jsonEncoder.encode(log) else { return }
        data.append("\n".data(using: .utf8) ?? .init())
        fileHandle?.write(data)
    }
}
