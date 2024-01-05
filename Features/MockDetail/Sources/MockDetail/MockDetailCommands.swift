//
//  MockDetailCommands.swift
//
//
//  Created by Yusuf Özgül on 5.01.2024.
//

import SwiftUI

public struct MockDetailCommands: Commands {
    public init() {}

    public var body: some Commands {
        CommandMenu("Mock") {
            Button("Remove") {
                NotificationCenter.default.post(.removeMock)
            }
        }
    }
}
