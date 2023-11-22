//
//  File.swift
//
//
//  Created by Yusuf Özgül on 2.09.2023.
//

import Foundation
import Combine

public protocol FileUrlBuilderInterface {
    /// Returns the URL for the "Domains" folder.
    ///
    /// - Returns: The URL for the "Domains" folder.
    /// - Throws: If constructing the URL encounters an error, a `FileUrlBuilderError` is thrown.
    func domainsFolderUrl() throws -> URL

    /// Returns the URL for a specific domain folder within the "Domains" folder.
    ///
    /// - Parameter mockDomain: The domain for which the folder URL is constructed.
    /// - Returns: The URL for the specified domain folder.
    /// - Throws: If constructing the URL encounters an error, a `FileUrlBuilderError` is thrown.
    func domainFolder(for mockDomain: String) throws -> URL

    /// Returns the URL for the "Mocks" folder within a specific domain.
    ///
    /// - Parameter mockDomain: The domain for which the "Mocks" folder URL is constructed.
    /// - Returns: The URL for the "Mocks" folder within the specified domain.
    /// - Throws: If constructing the URL encounters an error, a `FileUrlBuilderError` is thrown.
    func mocksFolderUrl(for mockDomain: String) throws -> URL

    /// Returns the URL for a specific mock list folder within the "Mocks" folder.
    ///
    /// - Parameters:
    ///   - mocksFolderURL: The URL of the "Mocks" folder.
    ///   - requestPath: The path of the mock request.
    ///   - method: The HTTP method of the mock request.
    /// - Returns: The URL for the specific mock list folder.
    func mockListFolderUrl(mocksFolderURL: URL, requestPath: String, method: String) -> URL

    /// Mock List Configured URL
    ///
    /// This function returns a configured URL for a specific combination of `requestPath`, `configPath`, and `method`. 
    ///
    /// - Parameters:
    ///   - mocksFolderURL: The URL of the folder where mock data is stored.
    ///   - requestPath: The path part of the requested URL.
    ///   - configPath: The path pattern in the configuration file.
    ///   - method: A string specifying the HTTP method.
    ///
    /// - Throws: It throws a `FileUrlBuilderError.urlError` if an invalid URL or mismatched path patterns are encountered.
    ///
    /// - Returns: The URL of the requested configuration file.
    ///
    /// - Note: If the path patterns are not aligned and do not include the '*' character, the function calls the `mockListFolderUrl` function to return the appropriate folder URL.
    func mockListConfiguredUrl(mocksFolderURL: URL, requestPath: String, configPath: String, method: String) throws -> URL

    /// Returns the URL for the "Configs" folder within a specific domain.
    ///
    /// - Parameter mockDomain: The domain for which the "Configs" folder URL is constructed.
    /// - Returns: The URL for the "Configs" folder within the specified domain.
    /// - Throws: If constructing the URL encounters an error, a `FileUrlBuilderError` is thrown.
    func configsFolderUrl(for mockDomain: String) throws -> URL

    /// Returns the URL for the "configs.json" file within a specific domain's "Configs" folder.
    ///
    /// - Parameter mockDomain: The domain for which the "configs.json" file URL is constructed.
    /// - Returns: The URL for the "configs.json" file within the specified domain's "Configs" folder.
    /// - Throws: If constructing the URL encounters an error, a `FileUrlBuilderError` is thrown.
    func configUrl(for mockDomain: String) throws -> URL

    /// Returns the URL for the "Plugins" folder within a specific domain.
    ///
    /// - Parameter mockDomain: The domain for which the "Plugins" folder URL is constructed.
    /// - Returns: The URL for the "Plugins" folder within the specified domain.
    /// - Throws: If constructing the URL encounters an error, a `FileUrlBuilderError` is thrown.
    func pluginFolderUrl(for mockDomain: String) throws -> URL

    /// Returns the URL for the "Plugins" folder.
    ///
    /// - Returns: The URL for the "Plugins" folder.
    /// - Throws: If constructing the URL encounters an error, a `FileUrlBuilderError` is thrown.
    func commonPluginFolderUrl() throws -> URL

    func isPathMatched(requestPath: String, configPath: String, pathMatchingRatio: Double) -> Bool
}

public enum FileUrlBuilderError: LocalizedError {
    case urlError

    public var errorDescription: String? {
        return switch self {
        case .urlError: "File url creation error"
        }
    }
}

public final class FileUrlBuilder: FileUrlBuilderInterface {
    @UserDefaultStorage("mockFolderFilePath") var mocksFolderPath: String = "/MockServer"
    private var folderPath: String {
        if mocksFolderPath.hasSuffix("/") { return mocksFolderPath }
        return mocksFolderPath + "/"
    }

    public init() {}

    public func domainsFolderUrl() throws -> URL {
        guard let url = URL(string: folderPath + "Domains/") else {
            throw FileUrlBuilderError.urlError
        }
        return url
    }

    public func domainFolder(for mockDomain: String) throws -> URL {
        guard let url = URL(string: try domainsFolderUrl().absoluteString + mockDomain) else {
            throw FileUrlBuilderError.urlError
        }
        return url
    }

    public func mocksFolderUrl(for mockDomain: String) throws -> URL {
        try domainFolder(for: mockDomain).appending(path: "Mocks")
    }

    public func mockListFolderUrl(mocksFolderURL: URL, requestPath: String, method: String) -> URL {
        mocksFolderURL.appending(path: requestPath).appending(path: method)
    }

    public func mockListConfiguredUrl(mocksFolderURL: URL, requestPath: String, configPath: String, method: String) throws -> URL {
        guard var requestPathComponents: [String] = URL(string: requestPath)?.pathComponents.drop(while: { $0.isEmpty || $0 == "/" }).reversed(),
              let configPathComponents: [String] = URL(string: configPath)?.pathComponents.drop(while: { $0.isEmpty || $0 == "/" }).reversed() else { throw FileUrlBuilderError.urlError }


        for (index, configPathComponent) in configPathComponents.enumerated() {
            guard configPathComponent != requestPathComponents[index] else { continue }

            if configPathComponent == "*" {
                requestPathComponents[index] = "*"
            } else {
                return mockListFolderUrl(mocksFolderURL: mocksFolderURL, requestPath: requestPath, method: method)
            }
        }

        return mockListFolderUrl(mocksFolderURL: mocksFolderURL, requestPath: requestPathComponents.reversed().joined(separator: "/"), method: method)
    }

    public func configsFolderUrl(for mockDomain: String) throws -> URL {
        guard let url = URL(string: folderPath + "Domains/" + mockDomain + "/Configs") else {
            throw FileUrlBuilderError.urlError
        }
        return URL(filePath: url.path())
    }

    public func configUrl(for mockDomain: String) throws -> URL {
        try configsFolderUrl(for: mockDomain).appending(path: "configs.json")
    }

    public func pluginFolderUrl(for mockDomain: String) throws -> URL {
        guard let url = URL(string: folderPath + "Domains/" + mockDomain + "/Plugins") else {
            throw FileUrlBuilderError.urlError
        }
        return URL(filePath: url.path())
    }

    public func commonPluginFolderUrl() throws -> URL {
        guard let url = URL(string: folderPath + "Plugins") else {
            throw FileUrlBuilderError.urlError
        }
        return URL(filePath: url.path())
    }

    public func isPathMatched(requestPath: String, configPath: String, pathMatchingRatio: Double) -> Bool {
        guard let requestPathComponents: [String] = URL(string: requestPath)?.pathComponents.drop(while: { $0.isEmpty || $0 == "/" }).reversed(),
              let configPathComponents: [String] = URL(string: configPath)?.pathComponents.drop(while: { $0.isEmpty || $0 == "/" }).reversed() else { return false }

        var controlPathComponents: [String] = []

        for (index, configPathComponent) in configPathComponents.enumerated() {
            guard configPathComponent != requestPathComponents[safe: index] && configPathComponent != "*" else {
                controlPathComponents.append(requestPathComponents[index])
                continue
            }
            return false
        }

        return Double(controlPathComponents.count) / Double(configPathComponents.count) >= pathMatchingRatio
    }
}
