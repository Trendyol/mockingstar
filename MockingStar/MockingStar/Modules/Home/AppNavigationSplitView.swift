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
import MockingStarCore
import PluginConfigs
import SwiftUI

struct AppNavigationSplitView: View {
    @Bindable private var navigationStore = NavigationStore.shared
    @SceneStorage("mockDomain") var mockDomain: String = ""
    @AppStorage("isOnboardingDone") private var isOnboardingDone: Bool = false
    private let mockListViewModel = MockListViewModel()
    private let onboardingCompleted = OnboardingCompleted.shared

    var body: some View {
        Group {
            if onboardingCompleted.completed && isOnboardingDone {
                NavigationSplitView {
                    SidebarView()
                        .frame(minWidth: 280)
                } detail: {
                    NavigationStack(path: $navigationStore.path) {
                        MockListView(viewModel: mockListViewModel)
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
                                case .appSettings:
                                    SettingsView()
                                case .logs:
                                    LogsView()
                                case .fileIntegrityCheck:
                                    FileIntegrityCheckView()
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
