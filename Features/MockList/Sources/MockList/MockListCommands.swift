//
//  MockListCommands.swift
//
//
//  Created by Yusuf Özgül on 5.01.2024.
//

import SwiftUI

public struct MockListCommands: Commands {
    public init() {}

    public var body: some Commands {
        CommandMenu("Mocks") {
            Button("Reload Mocks") {
                NotificationCenter.default.post(.reloadMocks)
            }

            Divider()

            Button("Select All Mocks") {
                NotificationCenter.default.post(.selectAllMocks)
            }

            Button("Unselect All Mocks") {
                NotificationCenter.default.post(.deselectAllMocks)
            }

            Divider()

            Button("Remove Mock(s)") {
                NotificationCenter.default.post(.removeMock)
            }

            Divider()

            Button("File Integrity Check") {
                NotificationCenter.default.post(.fileIntegrityCheck)
            }
        }
    }
}
