//
//  File.swift
//  
//
//  Created by Yusuf Özgül on 16.10.2023.
//

import Foundation

public final class FilePermissionHelper {
    private static var shared: FilePermissionHelper? = nil
    private let logger = Logger(category: "FilePermissionHelper")
    let fileBookMark: Data

    public init(fileBookMark: Data) {
        self.fileBookMark = fileBookMark
        logger.debug("initialize")
        FilePermissionHelper.shared = self
    }

    deinit {
        logger.debug("deinitialize")
        try? stopAccessingSecurityScopedResource()
    }

    /// Starts accessing a security-scoped resource using a bookmark.
    ///
    /// This function resolves the provided bookmark data into a URL and starts accessing the security-scoped resource.
    /// If successful, the resource can be accessed securely until `stopAccessingSecurityScopedResource()` is called.
    ///
    /// - Throws:
    ///   - If resolving the bookmark data or starting the access process encounters an error, a `FilePermissionHelperError` is thrown.
    public func startAccessingSecurityScopedResource() throws {
        do {
            var isStale = false
            let bookMarkUrl = try URL(resolvingBookmarkData: fileBookMark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

            guard bookMarkUrl.startAccessingSecurityScopedResource() else {
                logger.critical("startAccessingSecurityScopedResource failed")
                throw FilePermissionHelperError.fileBookMarkAccessingFailed
            }
        } catch {
            logger.critical("startAccessingSecurityScopedResource failed. Error: \(error)")
            throw FilePermissionHelperError.fileBookMarkLoadingError(error)
        }
    }

    /// Stops accessing a security-scoped resource using a bookmark.
    ///
    /// This function resolves the provided bookmark data into a URL and stops accessing the security-scoped resource.
    ///
    /// - Throws:
    ///   - If resolving the bookmark data or stopping the access process encounters an error, a `FilePermissionHelperError` is thrown.
    public func stopAccessingSecurityScopedResource() throws {
        do {
            var isStale = false
            let bookMarkUrl = try URL(resolvingBookmarkData: fileBookMark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            bookMarkUrl.stopAccessingSecurityScopedResource()
        } catch {
            logger.critical("stopAccessingSecurityScopedResource failed. Error: \(error)")
            throw FilePermissionHelperError.fileBookMarkLoadingError(error)
        }
    }
}

public enum FilePermissionHelperError: LocalizedError {
    case fileBookMarkLoadingError(Error)
    case fileBookMarkAccessingFailed

    public var errorDescription: String? {
        switch self {
        case .fileBookMarkLoadingError(let error):
            return "File BookMark loading error: \(error.localizedDescription)"
        case .fileBookMarkAccessingFailed:
            return "file Book Mark Accessing Failed"
        }
    }
}
