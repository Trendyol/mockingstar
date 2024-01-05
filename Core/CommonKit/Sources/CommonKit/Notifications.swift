//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 5.01.2024.
//

import Foundation

public extension Notification.Name {
    static var reloadMocks: Notification.Name {
        .init("RELOAD_MOCKS_NOTIFICATION")
    }

    static var selectAllMocks: Notification.Name {
        .init("SELECT_ALL_MOCKS_NOTIFICATION")
    }

    static var deselectAllMocks: Notification.Name {
        .init("DESELECT_ALL_MOCKS_NOTIFICATION")
    }

    static var removeMock: Notification.Name {
        .init("REMOVE_MOCK_NOTIFICATION")
    }

    static var reloadMockDomains: Notification.Name {
        .init("RELOAD_MOCK_DOMAINS_NOTIFICATION")
    }
}

public extension Notification {
    static var reloadMocks: Notification {
        .init(name: .reloadMocks)
    }

    static var selectAllMocks: Notification {
        .init(name: .selectAllMocks)
    }

    static var deselectAllMocks: Notification {
        .init(name: .deselectAllMocks)
    }

    static var removeMock: Notification {
        .init(name: .removeMock)
    }

    static var reloadMockDomains: Notification {
        .init(name: .reloadMockDomains)
    }
}
