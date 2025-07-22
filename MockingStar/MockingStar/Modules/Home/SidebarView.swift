//
//  SidebarView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 21.09.2023.
//

import CommonKit
import CommonViewsKit
import MockingStarCore
import SwiftUI
import TipKit

struct SidebarView: View {
    @Environment(MockDomainDiscover.self) private var domainDiscover: MockDomainDiscover
    @AppStorage("mockDomain") private var mockDomain: String = ""
    @SceneStorage("isConfigsExpanded") private var isConfigsExpanded: Bool = true
    private let navigationStore = NavigationStore.shared
    @StateObject private var pluginViewModel = SideBarPluginViewModel()
    private let logger = Logger(category: "SidebarView")

    var body: some View {
        List {
            Section("Servers") {
                SideBarServerView()
                SideBarWorkspaceView()
            }

            if #available(macOS 15.0, *) {
                if !Bundle.main.bundlePath.contains("/Application/") {
                    TipView(MoveApplicationTip())
                }
            }

            Section("App") {
                SideBarConfigsView(title: "Mock List", isSelected: NavigationStore.shared.path.isEmpty)
                    .onTapGesture {
                        NavigationStore.shared.path.removeAll()
                    }

                DisclosureGroup(isExpanded: $isConfigsExpanded) {
                    SideBarConfigsView(title: "Path Configs", isSelected: NavigationStore.shared.path.last == .configs_pathConfigs)
                        .onTapGesture { NavigationStore.shared.path.append(.configs_pathConfigs) }
                    SideBarConfigsView(title: "Query Configs", isSelected: NavigationStore.shared.path.last == .configs_queryConfigs)
                        .onTapGesture { NavigationStore.shared.path.append(.configs_queryConfigs) }
                    SideBarConfigsView(title: "Header Configs", isSelected: NavigationStore.shared.path.last == .configs_headerConfigs)
                        .onTapGesture { NavigationStore.shared.path.append(.configs_headerConfigs) }
                    SideBarConfigsView(title: "Logs", isSelected: NavigationStore.shared.path.last == .logs)
                        .onTapGesture { NavigationStore.shared.path.append(.logs) }
                } label: {
                    SideBarConfigsView(title: "Configs", isSelected: NavigationStore.shared.path.last == .configs)
                        .onTapGesture {
                            NavigationStore.shared.path.append(.configs)
                        }
                }
            }

            Section("Mock Domains") {
                ForEach(domainDiscover.domains, id: \.self) { domain in
                    SideBarMockDomainView(domain: domain, isSelected: domain == mockDomain)
                        .onTapGesture {
                            mockDomain = domain
                        }
                }
            }

            SideBarPluginView(viewModel: pluginViewModel)
            TipView(QuickDemoTip())
            Spacer()
            TipView(MenubarItemsTip())
            TipView(BugReport())
        }
        .task { try? await reloadMockDomains() }
        .onReceive(NotificationCenter.default.publisher(for: .reloadMockDomains)) { _ in
            Task { try await reloadMockDomains() }
        }
        .task(id: mockDomain) {
            try? await Task.sleep(for: .milliseconds(100))
            navigationStore.popToRoot()
        }
    }

    @MainActor
    func reloadMockDomains() async throws {
        try await domainDiscover.startDomainDiscovery()
        guard mockDomain.isEmpty || !domainDiscover.domains.contains(mockDomain) else { return }
        guard let firstDomain = domainDiscover.domains.first else {
            logger.warning("There is no mock domain.")
            return
        }

        mockDomain = firstDomain
    }
}

#Preview {
    SidebarView()
}

struct SideBarMockDomainView: View {
    let domain: String
    let isSelected: Bool
    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Text(domain)

            if isSelected {
                Image(systemName: "checkmark.circle")
            }
        }
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

struct SideBarConfigsView: View {
    let title: String
    let isSelected: Bool
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

struct MenubarItemsTip: Tip {
    var title: Text {
        Text("Menubar Actions")
    }

    var message: Text? {
        Text("To refresh Domain or Mock list, you can click on **Mocking Star** or **Mocks** from the Menubar and tap refresh.")
    }

    var image: Image? {
        Image(systemName: "arrow.clockwise")
    }
}

struct QuickDemoTip: Tip {
    var title: Text {
        Text("Quick Demo")
    }

    var message: Text? {
        Text("Test Mocking Star without client.")
    }

    var image: Image? {
        Image(systemName: "testtube.2")
    }

    var actions: [Action] {
        Action(title: "Open Playground") {
            @Environment(\.openWindow) var openWindow
            openWindow(id: "quick-demo")
        }
    }
}

struct BugReport: Tip {
    var title: Text {
        Text("Bug Report")
    }

    var message: Text? {
        Text(#"To report any issues, you can use the "Bug Report" section located under the "Help" menu in the menubar."#)
    }

    var image: Image? {
        Image(systemName: "ladybug.fill")
    }
}

@available(macOS 15.0, *)
struct MoveApplicationTip: Tip {
    var title: Text = Text("Please move Mocking Star to Applications folder")

    var actions: [Action] {
        Action(title: "Show in Finder") {
            NSWorkspace.shared.selectFile(Bundle.main.bundlePath,
                                          inFileViewerRootedAtPath: Bundle.main.bundleURL.deletingLastPathComponent().path())
        }
    }

    var options: [any TipOption] = [
        MaxDisplayDuration(20),
        MaxDisplayCount(100)
    ]
}
