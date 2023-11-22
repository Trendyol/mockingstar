//
//  File.swift
//
//
//  Created by Yusuf Özgül on 3.11.2023.
//

import CommonKit
import Foundation

public final class MockDirectoryMonitor: DirectoryMonitorInterface {
    public var invokedStartMonitoring = false
    public var invokedStartMonitoringCount = 0
    public var invokedStartMonitoringParameters: (url: URL, folderDidChangeHandler: () -> Void, Void)?
    public var invokedStartMonitoringParametersList: [(url: URL, folderDidChangeHandler: () -> Void, Void)] = []
    public func startMonitoring(url: URL, folderDidChangeHandler: @escaping () -> Void) {
        invokedStartMonitoring = true
        invokedStartMonitoringCount += 1
        invokedStartMonitoringParameters = (url, folderDidChangeHandler, ())
        invokedStartMonitoringParametersList.append((url, folderDidChangeHandler, ()))
    }

    public var invokedStopMonitoring = false
    public var invokedStopMonitoringCount = 0
    public func stopMonitoring() {
        invokedStopMonitoring = true
        invokedStopMonitoringCount += 1
    }
}
