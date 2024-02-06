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
    @SceneStorage("mockDomain") private var mockDomain: String = ""

    var body: some View {
        List {
            Section("Servers") {
                SideBarServerView()
            }

            Section("App") {
                SideBarMockDomainView(domain: "Mock List", isSelected: false)
                    .onTapGesture {
                        NavigationStore.shared.path.removeAll()
                    }

                DisclosureGroup {
                    SideBarConfigsView(title: "Path Configs").onTapGesture { NavigationStore.shared.path.append(.configs_pathConfigs) }
                    SideBarConfigsView(title: "Query Configs").onTapGesture { NavigationStore.shared.path.append(.configs_queryConfigs) }
                    SideBarConfigsView(title: "Header Configs").onTapGesture { NavigationStore.shared.path.append(.configs_headerConfigs) }
                    SideBarConfigsView(title: "Logs").onTapGesture { NavigationStore.shared.path.append(.logs) }
                } label: {
                    SideBarConfigsView(title: "Configs")
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

            SideBarPluginView()
            TipView(QuickDemoTip())
            Spacer()
            TipView(MenubarItemsTip())
            TipView(BugReport())
        }
        .task { try? await reloadMockDomains() }
        .onReceive(NotificationCenter.default.publisher(for: .reloadMockDomains)) { _ in
            Task { try await reloadMockDomains() }
        }
    }

    @MainActor
    func reloadMockDomains() async throws {
        try await domainDiscover.startDomainDiscovery()
        if mockDomain.isEmpty || !domainDiscover.domains.contains(mockDomain) {
            mockDomain = domainDiscover.domains.first ?? ""
        }
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
        Text(domain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(isSelected ? Color.accentColor : isHovering ? Color.accentColor.opacity(0.5) : Color.clear)
            .clipShape(.rect(cornerRadius: 10))
            .onHover { isHovering in
                withAnimation { self.isHovering = isHovering }
            }
    }
}

struct SideBarConfigsView: View {
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
