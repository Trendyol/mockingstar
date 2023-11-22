//
//  SettingsViewModel.swift
//  MockingStar
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import Foundation
import CommonKit
import SwiftUI
import Combine

@Observable
final class SettingsViewModel {
    private let logger = Logger(category: "SettingsViewModel")
    @ObservationIgnored @UserDefaultStorage("mockFolderFileBookMark") var mockFolderFileBookMark: Data? = nil
    @ObservationIgnored @UserDefaultStorage("mockFolderFilePath") var mockFolderFilePath: String = "/MockServer"
    @ObservationIgnored @UserDefaultStorage("httpServerPort") var httpServerPort: UInt16 = 8008

    init() {}

    func fileImported(result: Result<[URL], Error>) {
        switch result {
        case .success(let success):
            if let url = success.first {
                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        throw FilePermissionHelperError.fileBookMarkAccessingFailed
                    }

                    mockFolderFileBookMark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    mockFolderFilePath = url.path(percentEncoded: false)
                    url.stopAccessingSecurityScopedResource()
                } catch {
                    logger.critical("Update mocks folder path failed. Error: \(error)")
                }
            }
        case .failure(let failure):
            logger.error("Importing files failed. Error: \(failure)")
        }
    }
}
