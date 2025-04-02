//
//  NavigationStore.swift
//
//
//  Created by Yusuf Özgül on 20.09.2023.
//

import CommonKit
import SwiftUI

public enum Route: Hashable, Equatable {
    case mock(MockModel)
    case configs
    case configs_pathConfigs
    case configs_queryConfigs
    case configs_headerConfigs
    case pluginConfiguration(plugin: String)
    case logs
    case fileIntegrityCheck
}

@Observable
public final class NavigationStore {
    @ObservationIgnored public static let shared = NavigationStore()
    public var path: [Route] = []

    public func open(_ route: Route, animated: Bool = true) {
        guard Thread.isMainThread else {
            return DispatchQueue.main.async { self.open(route, animated: animated) }
        }

        if animated {
            withAnimation {
                path.append(route)
            }
        } else {
            path.append(route)
        }
    }

    public func pop(animated: Bool = true) {
        guard Thread.isMainThread else {
            return DispatchQueue.main.async { self.pop(animated: animated) }
        }

        if animated {
            withAnimation {
                path = path.dropLast()
            }
        } else {
            path = path.dropLast()
        }
    }

    public func popToRoot(animated: Bool = true) {
        guard Thread.isMainThread else {
            return DispatchQueue.main.async { self.popToRoot(animated: animated) }
        }

        if animated {
            withAnimation {
                path.removeAll()
            }
        } else {
            path.removeAll()
        }
    }
}
