//
//  Workspace.swift
//  CommonKit
//
//  Created by Yusuf Özgül on 26.03.2025.
//

import Foundation

public class Workspace: Codable, Identifiable, Equatable {
    public var id: String { name + path + bookmark.description }
    public var localId: String { createdAt.description + path + bookmark.description }
    public var name: String
    public let path: String
    public let bookmark: Data
    public var isSelected: Bool
    public var createdAt: Date

    public init(name: String, path: String, bookmark: Data) {
        self.name = name
        self.path = path
        self.bookmark = bookmark
        self.isSelected = false
        self.createdAt = Date()
    }

    public static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        lhs.id == rhs.id && lhs.isSelected == rhs.isSelected
    }
}

public extension [Workspace] {
    var current: Workspace? { first(where: \.isSelected) ?? first }
}
