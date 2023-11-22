//
//  PluginConfigView.swift
//
//
//  Created by Yusuf Özgül on 2.11.2023.
//

import CommonViewsKit
import SwiftUI

public struct PluginConfigView: View {
    private let plugin: String
    @Bindable private var viewModel: PluginConfigViewModel
    @SceneStorage("mockDomain") private var mockDomain: String = ""

    public init(plugin: String) {
        self.plugin = plugin
        viewModel = .init(plugin: plugin)
    }

    public var body: some View {
        Form {
            ForEach($viewModel.pluginConfigs) { $config in
                PluginConfigItemView(configUIModel: $config)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .overlay {
            if viewModel.pluginConfigs.isEmpty {
                ContentUnavailableView("Plugin Not Found", systemImage: "questionmark.folder.fill")
            }
        }
        .toolbar {
            ToolbarItem {
                ToolBarButton(title: "Save", icon: "tray.and.arrow.down", backgroundColor: .blue) {
                    viewModel.saveChanges()
                }
                .keyboardShortcut("s")
            }
        }
        .task(id: mockDomain) {  await viewModel.loadPlugins(for: mockDomain)}
        .task(id: viewModel.pluginConfigs) { viewModel.checkChanges() }
        .navigationTitle("\(plugin) Configurations")
        .modifier(ChangeConfirmationViewModifier(hasChange: $viewModel.shouldShowUnsavedIndicator) {
            viewModel.saveChanges()
        })
    }
}

#Preview {
    PluginConfigView(plugin: "test")
}
