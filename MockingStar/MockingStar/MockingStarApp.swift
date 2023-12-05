//
//  MockingStarApp.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 25.07.2023.
//

import CommonKit
import CommonViewsKit
import JSONEditor
import MockingStarCore
import SwiftUI
import TipKit

@main
struct MockingStarApp: App {
    var body: some Scene {
        WindowGroup {
            AppNavigationSplitView()
                .environment(NavigationStore.shared)
                .environment(MockDomainDiscover())
                .environment(NotificationManager.shared)
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
                .task {
                    await MainActor.run {
                        JSONEditorView.warmUp()
                    }
                }
        }

        Settings {
            SettingsView()
        }
    }
}
