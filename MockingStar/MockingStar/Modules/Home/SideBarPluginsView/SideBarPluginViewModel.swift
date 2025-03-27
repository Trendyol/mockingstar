//
//  SideBarPluginViewModel.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 2.11.2023.
//

import Foundation
import SwiftUI
import PluginCore

@Observable
final class SideBarPluginViewModel: ObservableObject {
    var plugins: [ConfigurablePluginModel] = []

    init() {}

    @MainActor
    func loadPlugins(for mockDomain: String) async {
        plugins.removeAll()
        plugins = await PluginCoreActor.shared.pluginCore(for: mockDomain).configAvailablePlugins()
    }
}
