//
//  MockNotificationManager.swift
//
//
//  Created by Yusuf Özgül on 4.12.2023.
//

import CommonViewsKit
import Foundation
import SwiftUI

public final class MockNotificationManager: NotificationManagerInterface {
    public init() { }
    
    public var invokedShow = false
    public var invokedShowCount = 0
    public var invokedShowParameters: (title: String, color: Color, dismissTime: TimeInterval, Void)?
    public var invokedShowParametersList: [(title: String, color: Color, dismissTime: TimeInterval, Void)] = []
    public func show(title: String, color: Color, dismissTime: TimeInterval) {
        invokedShow = true
        invokedShowCount += 1
        invokedShowParameters = (title, color, dismissTime, ())
        invokedShowParametersList.append((title, color, dismissTime, ()))
    }
}
