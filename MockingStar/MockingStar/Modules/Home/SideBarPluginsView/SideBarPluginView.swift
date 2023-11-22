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
    private let viewModel = SideBarPluginViewModel.shared
    @State private var lastMockFolderFilePath: String = ""
    @SceneStorage("mockDomain") private var mockDomain: String = ""
    @UserDefaultStorage("mockFolderFilePath") var mockFolderFilePath: String = "/MockServer"

    init() {
        lastMockFolderFilePath = mockFolderFilePath
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
        .task(id: lastMockFolderFilePath) { await viewModel.loadPlugins(for: mockDomain) }
        .onReceive(_mockFolderFilePath.projectedValue) { lastMockFolderFilePath = $0 }
    }
}

#Preview {
    SideBarPluginView()
}

struct SideBarPluginItemView: View {
    let title: String
    @State private var isHovering: Bool = false

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(isHovering ? Color.accentColor.opacity(0.5) : Color.clear)
            .clipShape(.rect(cornerRadius: 10))
            .onHover { isHovering in
                withAnimation { self.isHovering = isHovering }
            }
    }
}
