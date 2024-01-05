//
//  MenubarCommands.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 5.01.2024.
//

import CommonViewsKit
import MockDetail
import MockList
import SwiftUI
import PluginCore
import MockingStarCore

private extension MenubarCommands {
    enum Constant {
        static let githubURL = URL(string: "https://github.com/Trendyol/mockingstar")!
    }
}

struct MenubarCommands: Commands {
    @Bindable private var navigationStore = NavigationStore.shared

    var body: some Commands {
        if navigationStore.path.isEmpty {
            MockListCommands()
        } else if let path = navigationStore.path.last {
            switch path {
            case .mock:
                MockDetailCommands()
            default:CommandMenu("") {}
            }
        } else {
            CommandMenu("") {}
        }

        CommandGroup(after: .appSettings) {
            Button("Reload All Domains") {
                NotificationCenter.default.post(.reloadMockDomains)
            }

            Button("Reload All Plugins") {
                Task { await PluginCoreActor.shared.reloadAllPlugins() }
            }

            Divider()
        }

        CommandGroup(after: .help) {
            Divider()

            Link("Source Code", destination: Constant.githubURL)
            Link("Documentation", destination: Constant.githubURL)
        }
    }
}
