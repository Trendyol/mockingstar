//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 4.05.2024.
//

import Foundation
import Logging

public extension LogHandler {
    var metadata: Logging.Logger.Metadata {
        get { [:] }
        set { }
    }
    
    var logLevel: Logging.Logger.Level {
        get { .trace }
        set { }
    }

    subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { self.metadata[key] }
        set(newValue) { self.metadata[key] = newValue }
    }
}
