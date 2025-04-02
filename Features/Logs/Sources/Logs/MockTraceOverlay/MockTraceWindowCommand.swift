//
//  MockTraceWindowCommand.swift
//  MockList
//
//  Created by Yusuf Özgül on 28.03.2025.
//

import SwiftUI

public struct MockTraceWindowCommand: Commands {
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some Commands {
        CommandGroup(after: .windowList) {
            Button("Show Mock Trace Window") {
                openWindow(id: "mock-trace")
            }
            .keyboardShortcut("T", modifiers: [.command])
        }
    }
} 
