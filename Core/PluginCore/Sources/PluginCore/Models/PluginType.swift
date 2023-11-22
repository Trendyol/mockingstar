//
//  PluginType.swift
//  
//
//  Created by Yusuf Özgül on 1.11.2023.
//

import Foundation

/// App supported plugin types
public enum PluginType: String, CaseIterable, Codable {
    case requestReloader
    case liveRequestUpdater
    case mockError
    case mockDetailMessages
    
    /// Plugin file name based on enum case
    var fileName: String { rawValue + ".js"}
    /// Plugin name based on enum case
    public var pluginName: String { rawValue.map { $0.isUppercase ? " \($0)" : "\($0)" }.joined().capitalized }
}
