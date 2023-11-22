//
//  File.swift
//
//
//  Created by Yusuf Özgül on 3.11.2023.
//

import CommonKit
import Foundation

public final class MockFileStructureMonitor: FileStructureMonitorInterface {
    public init() { }
    
    public var invokedChangeHandlerSetter = false
    public var invokedChangeHandlerSetterCount = 0
    public var invokedChangeHandler: ((FileChangeEvent) -> Void?)!
    public var invokedChangeHandlerList: [(FileChangeEvent) -> Void] = []
    public var invokedChangeHandlerGetter = false
    public var invokedChangeHandlerGetterCount = 0
    public var stubbedChangeHandler: ((FileChangeEvent) -> Void)!
    public var changeHandler: (FileChangeEvent) -> Void {
        set {
            invokedChangeHandlerSetter = true
            invokedChangeHandlerSetterCount += 1
            invokedChangeHandler = newValue
            invokedChangeHandlerList.append(newValue)
        }
        get {
            invokedChangeHandlerGetter = true
            invokedChangeHandlerGetterCount += 1
            return stubbedChangeHandler
        }
    }

    public var invokedStartMonitoring = false
    public var invokedStartMonitoringCount = 0
    public var invokedStartMonitoringParameters: (url: URL, Void)?
    public var invokedStartMonitoringParametersList: [(url: URL, Void)] = []
    public func startMonitoring(url: URL) throws {
        invokedStartMonitoring = true
        invokedStartMonitoringCount += 1
        invokedStartMonitoringParameters = (url, ())
        invokedStartMonitoringParametersList.append((url, ()))
    }

    public var invokedStop = false
    public var invokedStopCount = 0
    public func stop() {
        invokedStop = true
        invokedStopCount += 1
    }
}
