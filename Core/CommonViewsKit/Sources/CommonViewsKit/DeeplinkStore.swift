//
//  DeeplinkStore.swift
//  CommonViewsKit
//
//  Created by Yusuf Özgül on 27.03.2025.
//

import SwiftUI

@Observable
public final class DeeplinkStore {
    @ObservationIgnored public static let shared = DeeplinkStore()
    public var deeplinks: [DeeplinkItem] = []
}

public enum DeeplinkItem: Hashable, Equatable {
    case openMock(id: String, domain: String)
}
