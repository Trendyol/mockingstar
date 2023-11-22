//
//  DirectoryMonitor.swift
//
//
//  Created by Yusuf Özgül on 25.09.2023.
//

import Combine
import Foundation

public protocol DirectoryMonitorInterface {
    func startMonitoring(url: URL, folderDidChangeHandler: @escaping () -> Void)
    func stopMonitoring()
}

/// DirectoryMonitor observes given folder for any changes
public class DirectoryMonitor: DirectoryMonitorInterface {
    private let logger = Logger(category: "DirectoryMonitor")
    private var monitoredDirectoryFileDescriptor: CInt = -1
    private let directoryMonitorQueue =  DispatchQueue(label: "directorymonitor", attributes: .concurrent)
    private var directoryMonitorSource: DispatchSource?

    public init() {}
    deinit {
        stopMonitoring()
    }
    
    /// Starts monitoring given url and notify with handler
    /// - Parameters:
    ///   - url: Folder url for monitoring
    ///   - folderDidChangeHandler: Handler for any changes
    public func startMonitoring(url: URL, folderDidChangeHandler: @escaping () -> Void) {
        logger.debug("start monitoring: \(url)")
        guard directoryMonitorSource == nil && monitoredDirectoryFileDescriptor == -1 else {
            logger.error("start monitoring error: FileDescriptor: \(self.monitoredDirectoryFileDescriptor)")
            return
        }

        monitoredDirectoryFileDescriptor = open((url as NSURL).fileSystemRepresentation, O_EVTONLY)
        directoryMonitorSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: monitoredDirectoryFileDescriptor, eventMask: DispatchSource.FileSystemEvent.write, queue: directoryMonitorQueue) as? DispatchSource

        directoryMonitorSource?.setEventHandler {
            folderDidChangeHandler()
        }

        directoryMonitorSource?.setCancelHandler{
            close(self.monitoredDirectoryFileDescriptor)
            self.monitoredDirectoryFileDescriptor = -1
            self.directoryMonitorSource = nil
            self.logger.debug("monitoring cancelled")
        }

        directoryMonitorSource?.resume()
    }
    
    /// Ends folder change monitoring
    public func stopMonitoring() {
        guard directoryMonitorSource != nil else { 
            logger.warning("Monitoring can not stop, already not monitoring")
            return
        }
        directoryMonitorSource?.cancel()
        logger.debug("Monitoring stopped")
    }
}
