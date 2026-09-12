//
//  AppNavigationSplitView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 21.09.2023.
//

import CommonKit
import CommonViewsKit
import Logs
import MockDetail
import MockDomainConfigs
import MockList
import Modifiers
import MockingStarCore
import PluginConfigs
import SwiftUI

struct AppNavigationSplitView: View {
    @Bindable private var navigationStore = NavigationStore.shared
    @AppStorage("mockDomain") var mockDomain: String = ""
    @AppStorage("isOnboardingDone") private var isOnboardingDone: Bool = false
    @State private var modifierCreationSeed: ModifierCreationSeed?
    @State private var modifierListViewModel = ModifierListViewModel()
    private let mockListViewModel = MockListViewModel()
    private let onboardingCompleted = OnboardingCompleted.shared
    private let deeplinkStore = DeeplinkStore.shared

    var body: some View {
        Group {
            if onboardingCompleted.completed && isOnboardingDone {
                NavigationSplitView {
                    SidebarView()
                        .frame(minWidth: 280)
                } detail: {
                    NavigationStack(path: $navigationStore.path) {
                        MockListView(viewModel: mockListViewModel) { seed in
                            modifierCreationSeed = seed
                        }
                            .navigationDestination(for: Route.self) { route in
                                switch route {
                                case .mock(let mock):
                                    MockDetailView(viewModel: .init(mockModel: mock, mockDomain: mockDomain))
                                case .configs:
                                    MockDomainConfigsView(viewModel: .init())
                                case .configs_pathConfigs:
                                    MockPathConfigurations(viewModel: .init())
                                case .configs_queryConfigs:
                                    MockQueryConfigurations(viewModel: .init())
                                case .configs_headerConfigs:
                                    MockHeaderConfigurations(viewModel: .init())
                                case .pluginConfiguration(let plugin):
                                    PluginConfigView(plugin: plugin)
                                case .logs:
                                    LogsView()
                                case .fileIntegrityCheck:
                                    FileIntegrityCheckView()
                                case .modifiers:
                                    ModifierListView(viewModel: modifierListViewModel)
                                case .modifier(let id, let previewSeed):
                                    ModifierDetailRouteView(
                                        modifierId: id,
                                        previewSeed: previewSeed
                                    )
                                }
                            }
                    }
                }
            } else if !isOnboardingDone {
                OnboardingView()
            } else {
                InitializeAppOnboardingView()
            }
        }
        .overlay { NotificationView() }
        .sheet(
            isPresented: Binding(
                get: { modifierCreationSeed != nil },
                set: { if !$0 { modifierCreationSeed = nil } }
            )
        ) {
            if let seed = modifierCreationSeed {
                ModifierCreateSheet(seed: seed, domain: mockDomain) { id, previewSeed in
                    modifierCreationSeed = nil
                    navigationStore.open(
                        .modifier(id: id, previewSeed: previewSeed)
                    )
                }
            }
        }
        .onChange(of: deeplinkStore.deeplinks) {
            switch deeplinkStore.deeplinks.last {
            case .openMock(_, let mockDomain) where self.mockDomain != mockDomain:
                self.mockDomain = mockDomain
            default: break
            }
        }
    }
}

#Preview {
    AppNavigationSplitView()
}

struct NotificationView: View {
    @Environment(NotificationManager.self) private var manager: NotificationManager

    var body: some View {
        HStack {
            Spacer()

            VStack {
                Spacer()

                ForEach(manager.notifications) {
                    NotificationBannerView(notification: $0)
                }
            }
            .padding()
        }
    }
}
