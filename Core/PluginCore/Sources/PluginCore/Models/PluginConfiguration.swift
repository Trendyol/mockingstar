//
//  PluginConfiguration.swift
//
//
//  Created by Yusuf Özgül on 1.11.2023.
//

import AnyCodable
import Foundation

/// A model presentation of Plugin Configuration
public struct PluginConfiguration: Codable, Hashable {
    public let key: String
    public let valueType: PluginConfigurationValueType
    public let value: AnyCodableModel?
    
    /// Initializer of ``PluginConfiguration``
    /// - Parameters:
    ///   - key: Plugin configuration key
    ///   - valueType: Type of plugin configuration value, available types: ``PluginConfigurationValueType``
    ///   - value: Value of plugin configuration
    public init(key: String, valueType: PluginConfigurationValueType, value: AnyCodableModel?) {
        self.key = key
        self.valueType = valueType
        self.value = value
    }
}

/// Plugin configuration value types
public enum PluginConfigurationValueType: String, Codable, Hashable {
    case text, number, bool
    case textArray, numberArray
}

/// A model representing plugin Configuration
public struct ConfigurablePluginModel: Hashable {
    public let pluginType: PluginType
    public let configs: [PluginConfiguration]

    public init(pluginType: PluginType, configs: [PluginConfiguration]) {
        self.pluginType = pluginType
        self.configs = configs
    }
}
