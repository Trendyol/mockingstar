//
//  FileMonitor.swift
//
//
//  Created by Yusuf Özgül on 12.10.2023.
//

import Foundation
import FileMonitor

public enum FileChangeEvent {
    case mockChange(url: URL)
    case mocksFolderChange(url: URL)
    case configChange
    case pluginChange(url: URL)
}

public protocol FileStructureMonitorInterface {
    var changeHandler: (FileChangeEvent) -> Void { get set }

    /// Starts monitoring a directory at the specified URL for file changes.
    ///
    /// - Parameters:
    ///   - url: The URL of the directory to be monitored.
    /// - Throws: If an error occurs during the monitoring setup or start, the error is logged, and the same error is thrown.
    func startMonitoring(url: URL) throws

    /// Stops monitoring the currently tracked directory.
    ///
    /// This function stops the monitoring process initiated by `startMonitoring(url:)`.
    /// It logs a debug message to indicate the monitoring has been stopped.
    func stop()
}

public final class FileStructureMonitor: FileStructureMonitorInterface, FileDidChangeDelegate {
    private let logger = Logger(category: "FileStructureMonitor")
    public var changeHandler: (FileChangeEvent) -> Void = { _ in }
    private var monitor: FileMonitor? = nil
    private var url: URL? = nil

    public init() {}
    deinit { stop() }

    public func startMonitoring(url: URL) throws {
        logger.debug("start monitoring: \(url)")
        self.url = url

        do {
            monitor = try FileMonitor(directory: url, delegate: self)
            try monitor?.start()
        } catch {
            logger.error("Monitoring failed: \(error)")
            throw error
        }
    }

    public func stop() {
        logger.debug("Monitoring stopped")
        monitor?.stop()
    }

    public func fileDidChanged(event: FileChange) {
        switch event {
        case .added(let fileURL): handleChange(fileURL: fileURL, event: event)
        case .deleted(let fileURL) : handleChange(fileURL: fileURL, event: event)
        case .changed(let fileURL): handleChange(fileURL: fileURL, event: event)
        }
    }

    /// Handles file changes detected by the FileMonitor.
    ///
    /// - Parameters:
    ///   - fileURL: The URL of the file that underwent a change.
    ///   - event: The type of change that occurred (e.g., creation, modification, deletion).
    ///
    /// This private function logs information about the file change and triggers appropriate change events based on the file's path.
    /// If the file change is related to specific directories or files, it calls the registered `changeHandler` closure with the corresponding change event.
    /// Unhandled file changes are logged as notices.
    private func handleChange(fileURL: URL, event: FileChange) {
        logger.info("File changed: \(event.description)")
        let fileURL = URL(filePath: fileURL.absoluteString)
        guard let url, !fileURL.path().hasSuffix(".DS_Store") else { return }

        let initialPath = fileURL.path(percentEncoded: false).replacingOccurrences(of: url.absoluteString, with: "")
        
        if initialPath.hasPrefix("/Mocks/") && initialPath.hasSuffix(".json") {
            changeHandler(.mockChange(url: fileURL))
        } else if initialPath.hasPrefix("/Mocks/") {
            changeHandler(.mocksFolderChange(url: fileURL))
        } else if initialPath.hasSuffix("/Configs/configs.json") {
            changeHandler(.configChange)
        } else if initialPath.contains("/Plugins/") {
            changeHandler(.pluginChange(url: fileURL))
        } else {
            logger.notice("Unhandled file change: \(event.description)")
        }
    }
}
