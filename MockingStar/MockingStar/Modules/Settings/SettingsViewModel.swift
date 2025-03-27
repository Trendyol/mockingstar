//
//  SettingsViewModel.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import Foundation
import CommonKit
import SwiftUI

@Observable
final class SettingsViewModel {
    private let logger = Logger(category: "SettingsViewModel")
    @ObservationIgnored @UserDefaultStorage("httpServerPort") var httpServerPort: UInt16 = 8008

    @ObservationIgnored
    var workspaces: [Workspace] {
        get {
            access(keyPath: \.workspaces)
            @UserDefaultStorage("workspaces") var workspaces: [Workspace] = []
            return workspaces
        } set {
            withMutation(keyPath: \.workspaces) {
                @UserDefaultStorage("workspaces") var workspaces: [Workspace] = []
                workspaces = newValue
            }
        }
    }

    init() {}

    func fileImported(result: Result<[URL], Error>) {
        switch result {
        case .success(let success):
            if let url = success.first {
                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        throw FilePermissionHelperError.fileBookMarkAccessingFailed
                    }

                    let mockFolderFileBookMark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    let mockFolderFilePath = url.path(percentEncoded: false)
                    workspaces.append(Workspace(name: "Workspace \(url.lastPathComponent)", path: mockFolderFilePath, bookmark: mockFolderFileBookMark))
                    NotificationCenter.default.post(name: .workspacesUpdated, object: nil)
                    url.stopAccessingSecurityScopedResource()
                } catch {
                    logger.critical("Update mocks folder path failed. Error: \(error)")
                }
            }
        case .failure(let failure):
            logger.error("Importing files failed. Error: \(failure)")
        }
    }

    func removeWorkspace(_ workspace: Workspace) {
        workspaces.removeAll(where: { $0 == workspace })
        NotificationCenter.default.post(name: .workspacesUpdated, object: nil)
    }

    func workspaceRenamed(workspace: Workspace, newName: String) {
        let _workspaces = workspaces
        guard let index = _workspaces.firstIndex(where: { $0 == workspace }) else { return }
        _workspaces[index].name = newName
        workspaces = _workspaces
        NotificationCenter.default.post(name: .workspacesUpdated, object: nil)
    }
}
