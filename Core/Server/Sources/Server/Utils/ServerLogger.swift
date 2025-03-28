//
//  ServerLogger.swift
//  
//
//  Created by Yusuf Özgül on 4.05.2024.
//


import CommonKit
import Foundation
import FlyingSocks

extension Logger: Logging, @unchecked Sendable {
    public func logDebug(_ debug: @autoclosure () -> String) {
        self.debug(debug())
    }
    
    public func logInfo(_ info: @autoclosure () -> String) {
        let info = info()
        guard !info.contains("close connection") && !info.contains("open connection") else { return }
        self.info(info)
    }
    
    public func logWarning(_ warning: @autoclosure () -> String) {
        self.warning(warning())
    }
    
    public func logError(_ error: @autoclosure () -> String) {
        self.error(error())
    }
    
    public func logCritical(_ critical: @autoclosure () -> String) {
        self.critical(critical())
    }
}
