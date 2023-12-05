//
//  PluginConfigViewModel.swift
//
//
//  Created by Yusuf Özgül on 2.11.2023.
//

import CommonKit
import CommonViewsKit
import Foundation
import PluginCore
import SwiftUI

@Observable
final class PluginConfigViewModel {
    private let plugin: String
    private var pluginType: PluginType? = nil
    private var pluginCore: PluginInterface? = nil
    private var originalPluginConfigs: [PluginConfigurationUIModel] = []
    private let manager: NotificationManager = .shared
    var shouldShowUnsavedIndicator: Bool = false
    var pluginConfigs: [PluginConfigurationUIModel] = []
    @ObservationIgnored @UserDefaultStorage("_") var pluginConfigStorage: [PluginConfiguration] = []

    init(plugin: String) {
        self.plugin = plugin
    }

    /// Asynchronously loads plugins and their configurations for the specified mock domain.
    func loadPlugins(for mockDomain: String) async {
        @UserDefaultStorage(mockDomain + plugin) var pluginConfigStorage: [PluginConfiguration] = []
        self._pluginConfigStorage = _pluginConfigStorage

        let pluginCore = await PluginCoreActor.shared.pluginCore(for: mockDomain)
        self.pluginCore = pluginCore

        guard let pluginModel = pluginCore.configAvailablePlugins().first(where: { $0.pluginType.rawValue == plugin }) else { return }

        pluginType = pluginModel.pluginType
        pluginConfigs = pluginModel.configs.map { config in
            let savedValue = pluginConfigStorage.first(where: { $0.key == config.key })?.value?.value
            let value: PluginConfigurationTypeViewModel?
            if let savedValue {
                if let data = savedValue as? String {
                    value = .text(data)
                } else if let data = savedValue as? Double {
                    value = .number(data)
                } else if let data = savedValue as? Bool {
                    value = .bool(data)
                } else if let data = savedValue as? [String] {
                    value = .textArray(data)
                } else if let data = savedValue as? [Double] {
                    value = .numberArray(data)
                } else {
                    value = nil
                }
            } else {
                value = nil
            }

            return .init(key: config.key, valueType: config.valueType, value: value)
        }
        originalPluginConfigs = pluginConfigs
    }

    /// Saves changes made to plugin configurations.
    func saveChanges() {
        pluginConfigStorage = pluginConfigs.map {
            .init(key: $0.key,
                  valueType: $0.valueType,
                  value: .init($0.value.rawValue))
        }
        originalPluginConfigs = pluginConfigs
        checkChanges()
        manager.show(title: "All changes saved", color: .green)
    }

    /// Checks if there are unsaved changes in plugin configurations.
    func checkChanges() {
        shouldShowUnsavedIndicator = originalPluginConfigs != pluginConfigs
    }
}
