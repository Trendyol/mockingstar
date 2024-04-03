// The Swift Programming Language
// https://docs.swift.org/swift-book

import CommonKit
import Foundation

public protocol PluginInterface {
    func configAvailablePlugins() -> [ConfigurablePluginModel]
    func requestReloaderPlugin(request: URLRequestModel) throws -> URLRequestModel
    func liveRequestPlugin(request: URLRequestModel) throws -> URLRequestModel
    func mockErrorPlugin(message: String) throws -> String
    func mockDetailMessagePlugin(mock: MockModel) throws -> String
    func asyncMockDetailMessagePlugin(mock: MockModel) async throws -> String
}

/// MockingStar Core Plugin helper, automatically loads and execute plugins
public final class Plugin {
    private let logger = Logger(category: "Plugin")
    private let mockDomain: String
    
    /// Initializer of Plugin class
    /// - Parameters:
    ///   - fileUrlBuilder: Common or domain plugins folder url builder
    ///   - fileManager: File manager
    ///   - domainFileStructureMonitor: File change observer of domain plugins
    ///   - commonFileStructureMonitor: File change observer of common plugins
    ///   - mockDomain: Selected mock domain
    init(mockDomain: String) {
        self.mockDomain = mockDomain
    }
    
    /// All type of plugins and its configuration which is configurable plugins
    /// - Returns: Plugin and its configurations
    ///
    /// All plugin configurable but plugin JavaScript file must define `config` variable and it shouldn't empty array.
    public func configAvailablePlugins() -> [ConfigurablePluginModel] {
        return []
    }
}

extension Plugin: PluginInterface {
    public func requestReloaderPlugin(request: URLRequestModel) throws -> URLRequestModel {
        request
    }

    public func liveRequestPlugin(request: URLRequestModel) throws -> URLRequestModel {
        request
    }

    public func mockErrorPlugin(message: String) throws -> String {
        String()
    }

    public func mockDetailMessagePlugin(mock: MockModel) throws -> String {
        String()
    }

    public func asyncMockDetailMessagePlugin(mock: MockModel) async throws -> String {
        String()
    }
}

import AnyCodable

public struct ConfigurablePluginModel: Hashable {
    public let pluginType: PluginType
    public let configs: [PluginConfiguration]

    public init(pluginType: PluginType, configs: [PluginConfiguration]) {
        self.pluginType = pluginType
        self.configs = configs
    }
}

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

/// A model representing a http request.
public struct URLRequestModel: Codable, Equatable {
    public let url: String
    public let headers: [String: String]
    public let body: String
    public let method: String

    public init(url: String, headers: [String : String], body: String, method: String) {
        self.url = url
        self.headers = headers
        self.body = body
        self.method = method
    }
}
