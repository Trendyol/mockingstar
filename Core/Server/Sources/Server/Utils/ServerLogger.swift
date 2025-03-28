//
//  ServerLogger.swift
//  
//
//  Created by Yusuf Özgül on 4.05.2024.
//


import CommonKit
import Foundation
import FlyingSocks

extension Logger: @retroactive Logging, @unchecked Sendable {
    public func logDebug(_ debug: String) {
        self.debug(debug)
    }
    
    public func logInfo(_ info: String) {
        guard !info.contains("close connection") && !info.contains("open connection") else { return }
        self.info(info)
    }
    
    public func logWarning(_ warning: String) {
        self.warning(warning)
    }
    
    public func logError(_ error: String) {
        self.error(error)
    }
    
    public func logCritical(_ critical: String) {
        self.critical(critical)
    }
}
