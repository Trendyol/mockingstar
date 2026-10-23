//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 1.11.2023.
//

import Foundation
import CommonKit

public protocol PluginCoreActorInterface {
    func pluginCore(for mockDomain: String) async -> PluginInterface
}

/// Singleton actor for plugins, same plugin instance usable whole session.
public actor PluginCoreActor: PluginCoreActorInterface {
    private var plugins: [String: Plugin] = [:]
    public static let shared = PluginCoreActor()
    private let fileUrlBuilder: FileUrlBuilderInterface
    private let settingsRoot: URL?
    public init(fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder(), settingsRoot: URL? = nil) {
        self.fileUrlBuilder = fileUrlBuilder; self.settingsRoot = settingsRoot
    }
    
    /// Plugins for given domain
    /// - Parameter mockDomain: Current mock domain
    /// - Returns: ``Plugin`` instance
    public func pluginCore(for mockDomain: String) -> PluginInterface {
        if let plugin = plugins[mockDomain] {
            return plugin
        }

        let plugin = Plugin(fileUrlBuilder: fileUrlBuilder, settingsRoot: settingsRoot, mockDomain: mockDomain)
        plugins[mockDomain] = plugin
        return plugin
    }

    public func reloadAllPlugins() {
        plugins.removeAll()
    }
}
