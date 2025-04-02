//
//  MockingStarApp.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 25.07.2023.
//

import CommonKit
import CommonViewsKit
import JSONEditor
import Logs
import MockingStarCore
import Sparkle
import SwiftUI
import TipKit

@main
struct MockingStarApp: App {
    private let updaterController: SPUStandardUpdaterController
    @AppStorage("resetTipKitOnNextLaunch") private var resetTipKitOnNextLaunch = false

    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            AppNavigationSplitView()
                .environment(NavigationStore.shared)
                .environment(MockDomainDiscover())
                .environment(NotificationManager.shared)
                .task {
                    await MainActor.run {
                        JSONEditorView.warmUp()
                    }
                }
                .task {
                    if resetTipKitOnNextLaunch {
                        try? Tips.resetDatastore()
                        resetTipKitOnNextLaunch = false
                    }
                    
                    try? Tips.configure([.datastoreLocation(.applicationDefault)])
                }
                .task {
                    if !updaterController.updater.automaticallyChecksForUpdates {
                        updaterController.updater.checkForUpdatesInBackground()
                    }
                }
        }
        .defaultSize(width: (NSScreen.main?.visibleFrame.size.width ?? 1000) / 1.5, height: (NSScreen.main?.visibleFrame.size.height ?? 600) / 1.5)
        .commands {
            SidebarCommands()
            MenubarCommands()
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            MockTraceWindowCommand()
        }

        Window("Mocking Star Playground", id: "quick-demo") {
            QuickDemo()
        }

        MockTraceScene()

        Settings {
            SettingsView(updater: updaterController.updater)
        }
    }
}
