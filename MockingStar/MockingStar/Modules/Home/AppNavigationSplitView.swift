//
//  AppNavigationSplitView.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 21.09.2023.
//

import Combine
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
    @State private var initializeAppOnboardingDone: Bool = false
    @State private var lastMockFolderFilePath: String = ""
    @Bindable private var navigationStore = NavigationStore.shared
    @SceneStorage("mockDomain") var mockDomain: String = ""
    @AppStorage("isOnboardingDone") private var isOnboardingDone: Bool = false
    @UserDefaultStorage("mockFolderFilePath") var mockFolderFilePath: String = "/MockServer"
    private let mockListViewModel = MockListViewModel()

    init() {
        lastMockFolderFilePath = mockFolderFilePath
    }

    var body: some View {
        Group {
            if initializeAppOnboardingDone && isOnboardingDone {
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
                                }
                            }
                    }
                }
            } else if !isOnboardingDone {
                OnboardingView()
            } else {
                InitializeAppOnboardingView {
                    initializeAppOnboardingDone = true
                }
            }
        }
        .onReceive(_mockFolderFilePath.projectedValue) { lastMockFolderFilePath = $0 }
        .task(id: lastMockFolderFilePath, priority: .userInitiated) {
            initializeAppOnboardingDone = false
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
