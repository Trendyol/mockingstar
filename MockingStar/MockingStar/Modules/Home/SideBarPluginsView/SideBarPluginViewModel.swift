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
final class SideBarPluginViewModel {
    static let shared = SideBarPluginViewModel()
    var plugins: [ConfigurablePluginModel] = []

    private init() {}

    @MainActor
    func loadPlugins(for mockDomain: String) async {
        plugins.removeAll()
        plugins = await PluginCoreActor.shared.pluginCore(for: mockDomain).configAvailablePlugins()
    }
}
