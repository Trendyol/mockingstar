//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 1.11.2023.
//

import Foundation

/// Singleton actor for plugins, same plugin instance usable whole session.
public actor PluginCoreActor {
    private var plugins: [String: Plugin] = [:]
    public static let shared = PluginCoreActor()
    
    /// Plugins for given domain
    /// - Parameter mockDomain: Current mock domain
    /// - Returns: ``Plugin`` instance
    public func pluginCore(for mockDomain: String) -> Plugin {
        if let plugin = plugins[mockDomain] {
            return plugin
        }

        let plugin = Plugin(mockDomain: mockDomain)
        plugins[mockDomain] = plugin
        return plugin
    }
}
