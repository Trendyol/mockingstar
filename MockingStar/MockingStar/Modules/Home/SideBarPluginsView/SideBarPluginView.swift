//
//  SideBarPluginView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 2.11.2023.
//

import CommonKit
import CommonViewsKit
import SwiftUI

struct SideBarPluginView: View {
    private let viewModel: SideBarPluginViewModel
    @AppStorage("mockDomain") private var mockDomain: String = ""

    init(viewModel: SideBarPluginViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Section("Plugins") {
            ForEach(viewModel.plugins, id: \.self) { plugin in
                SideBarPluginItemView(title: plugin.pluginType.pluginName)
                    .onTapGesture {
                        NavigationStore.shared.path.append(.pluginConfiguration(plugin: plugin.pluginType.rawValue))
                    }
            }
        }
        .task(id: mockDomain) { await viewModel.loadPlugins(for: mockDomain) }
        .onReceive(NotificationCenter.default.publisher(for: .workspacesUpdated)) { _ in
            Task { await viewModel.loadPlugins(for: mockDomain) }
        }
    }
}

#Preview {
    SideBarPluginView(viewModel: SideBarPluginViewModel())
}

struct SideBarPluginItemView: View {
    let title: String
    @State private var isHovering: Bool = false

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHovering ? Color.accentColor.opacity(0.5) : Color.clear)
            .clipShape(.rect(cornerRadius: 6))
            .onHover { isHovering in
                withAnimation { self.isHovering = isHovering }
            }
    }
}
