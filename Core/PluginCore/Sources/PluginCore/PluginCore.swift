// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import CommonKit

/// MockingStar Core Plugin helper, automatically loads and execute plugins
public final class Plugin {
    private let logger = Logger(category: "Plugin")
    private let fileManager: FileManagerInterface
    private let fileUrlBuilder: FileUrlBuilderInterface
    private var domainFileStructureMonitor: FileStructureMonitorInterface
    private var commonFileStructureMonitor: FileStructureMonitorInterface
    private let mockDomain: String
    private var plugins: [PluginType: String] = [:]
    var storage: [PluginType: UserDefaultStorage<[PluginConfiguration]>] = [:]
    
    /// Initializer of Plugin class
    /// - Parameters:
    ///   - fileUrlBuilder: Common or domain plugins folder url builder
    ///   - fileManager: File manager
    ///   - domainFileStructureMonitor: File change observer of domain plugins
    ///   - commonFileStructureMonitor: File change observer of common plugins
    ///   - mockDomain: Selected mock domain
    init(fileUrlBuilder: FileUrlBuilderInterface = FileUrlBuilder(),
         fileManager: FileManagerInterface = FileManager.default,
         domainFileStructureMonitor: FileStructureMonitorInterface = FileStructureMonitor(),
         commonFileStructureMonitor: FileStructureMonitorInterface = FileStructureMonitor(),
         mockDomain: String) {
        self.fileManager = fileManager
        self.fileUrlBuilder = fileUrlBuilder
        self.domainFileStructureMonitor = domainFileStructureMonitor
        self.commonFileStructureMonitor = commonFileStructureMonitor
        self.mockDomain = mockDomain
        loadAllPlugins()
        watchDomainPlugins()
        watchCommonPlugins()
    }
    
    /// File change watcher
    ///
    /// Whenever a plugin file modified, watcher automatically reload plugin.
    private func watchDomainPlugins() {
        logger.debug("Start watching domain plugins")
        do {
            domainFileStructureMonitor.stop()
            try domainFileStructureMonitor.startMonitoring(url: try fileUrlBuilder.pluginFolderUrl(for: mockDomain))

            domainFileStructureMonitor.changeHandler = { [weak self] event in
                guard let self, case .pluginChange(let url) = event  else { return }
                logger.info("Domain Plugins folder change detected, reload necessary plugins")
                PluginType.allCases
                    .filter { url.absoluteString.hasSuffix($0.fileName )}
                    .forEach {
                        self.plugins.removeValue(forKey: $0)
                    }
                loadAllPlugins()
            }
        } catch {
            logger.error("Watch Domain configs error: \(error)")
            return
        }
    }

    /// File change watcher
    ///
    /// Whenever a plugin file modified, watcher automatically reload plugin.
    private func watchCommonPlugins() {
        logger.debug("Start watching common plugins")
        do {
            commonFileStructureMonitor.stop()
            try commonFileStructureMonitor.startMonitoring(url: try fileUrlBuilder.commonPluginFolderUrl())

            commonFileStructureMonitor.changeHandler = { [weak self] event in
                guard let self, case .pluginChange(let url) = event  else { return }
                logger.info("Common  Plugins folder change detected, reload necessary plugins")
                PluginType.allCases
                    .filter { url.absoluteString.hasSuffix($0.fileName )}
                    .forEach {
                        self.plugins.removeValue(forKey: $0)
                    }
                loadAllPlugins()
            }
        } catch {
            logger.error("Watch Common configs error: \(error)")
            return
        }
    }

    private func loadAllPlugins() {
        PluginType.allCases.forEach(loadPlugin(type:))
    }
    
    /// Plugin loader
    /// - Parameter type: case of ``PluginType`` enum
    /// 
    /// Normally plugins not require always loaded, it can loadable during plugin usage, but UI must show configurable plugins so app needs always loaded plugins.
    ///
    /// There are two folder for plugins,
    ///
    ///     1. Common Plugins
    ///     2. Mock Domain Plugins
    ///
    ///  If you split your mock domains for each teams etc, each team can have own plugins
    ///  or all teams / mock domains can use same common plugin.
    ///
    ///  ⚠️ App always prefer mock domain plugins
    private func loadPlugin(type: PluginType) {
        guard plugins[type] == nil else { return }
        @UserDefaultStorage(mockDomain + type.rawValue) var configStorage: [PluginConfiguration] = []
        storage[type] = _configStorage

        let fileURL: URL

        do {
            let pluginURL: URL = try fileUrlBuilder.pluginFolderUrl(for: mockDomain).appending(path: type.fileName)
            let commonPluginURL: URL = try fileUrlBuilder.commonPluginFolderUrl().appending(path: type.fileName)

            if fileManager.fileExist(atPath: pluginURL.path()) {
                logger.info("\(mockDomain) has no plugin")
                fileURL = pluginURL
            } else if fileManager.fileExist(atPath: commonPluginURL.path()) {
                logger.info("Project has no plugin")
                fileURL = commonPluginURL
            } else {
                return
            }
        } catch {
            logger.error("Finding Plugin File error: \(error)")
            return
        }

        do {
            plugins[type] =  try fileManager.readFile(at: fileURL)
        } catch {
            logger.error("Reading Plugin File error: \(error), URL: \(fileURL)")
            return
        }
    }
    
    /// All type of plugins and its configuration which is configurable plugins
    /// - Returns: Plugin and its configurations
    ///
    /// All plugin configurable but plugin JavaScript file must define `config` variable and it shouldn't empty array.
    public func configAvailablePlugins() -> [ConfigurablePluginModel] {
        let plugin = ConfigurablePluginJSBridge()

        return plugins.compactMap { type, code in
            plugin.loadFrom(jsCode: code, resetContext: true)

            if let configs = try? plugin.config, !configs.isEmpty {
                return .init(pluginType: type, configs: configs)
            }
            return nil
        }
    }
}

public extension Plugin {
    /// During Request reloader page in mock detail page, app update original plugin with `requestReloader` plugin.
    /// - Parameter request: original http request as ``URLRequestModel``
    /// - Returns: Updated http request as ``URLRequestModel``
    func requestReloaderPlugin(request: URLRequestModel) throws -> URLRequestModel {
        guard let pluginCode = plugins[.requestReloader] else { return request }

        let plugin = RequestReloaderPluginJSBridge()
        plugin.loadFrom(jsCode: pluginCode)
        plugin.jsContext.setObject(PluginsUtil(context: plugin.jsContext), forKeyedSubscript: "util" as NSString)

        if let configs = storage[.requestReloader]?.wrappedValue {
            try plugin.setConfig(configs)
        }

        return try plugin.updateRequest(request: request)
    }

    /// If a mock not found and has no `disableLive` flag, app request with original request, before that `liveRequestUpdater` plugin can modify original request
    /// - Parameter request: original http request as ``URLRequestModel``
    /// - Returns: Updated http request as ``URLRequestModel``
    func liveRequestPlugin(request: URLRequestModel) throws -> URLRequestModel {
        guard let pluginCode = plugins[.liveRequestUpdater] else { return request }

        let plugin = LiveRequestPluginJSBridge()
        plugin.loadFrom(jsCode: pluginCode)
        plugin.jsContext.setObject(PluginsUtil(context: plugin.jsContext), forKeyedSubscript: "util" as NSString)

        if let configs = storage[.liveRequestUpdater]?.wrappedValue {
            try plugin.setConfig(configs)
        }

        return try plugin.updateRequest(request: request)
    }

    /// If a mock not found and has `disableLive` flag, app can not provide success response and it returns fail. `mockError` plugin defines return type and source application can understand problem.
    /// - Parameter message: Error message provides from mock server
    /// - Returns: Response body, should be string
    func mockErrorPlugin(message: String) throws -> String {
        guard let pluginCode = plugins[.mockError] else { return .init() }

        let plugin = MockErrorPluginJSBridge()
        plugin.loadFrom(jsCode: pluginCode)
        plugin.jsContext.setObject(PluginsUtil(context: plugin.jsContext), forKeyedSubscript: "util" as NSString)

        if let configs = storage[.mockError]?.wrappedValue {
            try plugin.setConfig(configs)
        }

        return try plugin.defaultResponseModel(message: message)
    }
    
    /// Mock detail page can offer more information about mock, `mockDetailMessages` can provide more information about mock
    /// - Parameter mock: A model representing mock detail: ``CommonKit/MockModel``.
    /// - Returns: Plugin markdown/plain text response
    func mockDetailMessagePlugin(mock: MockModel) throws -> String {
        guard let pluginCode = plugins[.mockDetailMessages] else { return .init() }

        let plugin = MockDetailHelperPluginJSBridge()
        plugin.loadFrom(jsCode: pluginCode)
        plugin.jsContext.setObject(PluginsUtil(context: plugin.jsContext), forKeyedSubscript: "util" as NSString)

        if let configs = storage[.mockDetailMessages]?.wrappedValue {
            try plugin.setConfig(configs)
        }

        return try plugin.mockDetailMessages(path: mock.metaData.url.path(percentEncoded: false),
                                             scenario: mock.metaData.scenario,
                                             mock: mock)
    }

    /// Mock detail page can offer more information about mock, `mockDetailMessages` can provide more information about mock
    ///
    /// Difference between mockDetailMessagePlugin and asyncMockDetailMessagePlugin its name, async or not.
    /// Async method can usable for http request
    /// - Parameter mock: A model representing mock detail: ``CommonKit/MockModel``.
    /// - Returns: Plugin markdown/plain text response
    func asyncMockDetailMessagePlugin(mock: MockModel) async throws -> String {
        guard let pluginCode = plugins[.mockDetailMessages] else { return .init() }

        let plugin = MockDetailHelperPluginJSBridge()
        plugin.loadFrom(jsCode: pluginCode)
        plugin.jsContext.setObject(PluginsUtil(context: plugin.jsContext), forKeyedSubscript: "util" as NSString)

        if let configs = storage[.mockDetailMessages]?.wrappedValue {
            try plugin.setConfig(configs)
        }

        return try await plugin.asyncMockDetailMessages(mock: mock)
    }
}
