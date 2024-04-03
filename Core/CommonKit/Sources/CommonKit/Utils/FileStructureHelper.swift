//
//  FileStructureHelper.swift
//
//
//  Created by Yusuf Özgül on 31.08.2023.
//

import Foundation

/// Default File Tree
/// MockServer:
///     |-> Domain (eg: LocalDevelopment)
///         |-> Mocks
///             |-> product/v1/product/v1_12345.json
///         |-> Configs
///     |-> Plugins
///     |-> Template Configs

public protocol FileStructureHelperInterface {
    /// Checks the file structure to ensure the existence of specified folders.
    ///
    /// This function iterates through a set of folder paths and verifies whether each specified folder exists.
    ///
    /// - Returns: `true` if all specified folders exist, otherwise `false`.
    func fileStructureCheck() -> Bool

    /// Checks the file structure within a specific domain to ensure the existence of specified folders.
    ///
    /// This function iterates through a set of folder paths within a domain and verifies whether each specified folder exists.
    ///
    /// - Parameter mockDomain: The domain for which the file structure is checked.
    /// - Returns: `true` if all specified folders within the domain exist, otherwise `false`.
    func domainFileStructureCheck(mockDomain: String) -> Bool

    /// Creates the specified file structure by creating folders if they do not exist.
    ///
    /// This function iterates through a set of folder paths and creates each folder if it does not already exist.
    ///
    /// - Throws: If creating any of the specified folders encounters an error, a corresponding error is thrown.
    func createFileStructure() throws

    /// Creates the specified file structure within a specific domain by creating folders if they do not exist.
    ///
    /// This function iterates through a set of folder paths within a domain and creates each folder if it does not already exist.
    ///
    /// - Parameter mockDomain: The domain for which the file structure is created.
    /// - Throws: If creating any of the specified folders encounters an error, a corresponding error is thrown.
    func createDomainFileStructure(mockDomain: String) throws
    func repairFileStructure() throws
    func repairDomainFileStructure(mockDomain: String) throws
}

public final class FileStructureHelper {
    @UserDefaultStorage("mockFolderFilePath") var mocksFolderPath: String = "/MockServer"
    private let folderPaths: [String] = [
        "Domains",
        "Plugins",
    ]
    private let domainFolderPaths: [String] = [
        "Domains/%@/Mocks",
        "Domains/%@/Configs",
        "Domains/%@/Plugins",
    ]
    private let fileNames: [String] = [
        "Configs.json",
    ]
    private let fileManager: FileManagerInterface

    public init(fileManager: FileManagerInterface = FileManager.default) {
        self.fileManager = fileManager
    }
}

extension FileStructureHelper: FileStructureHelperInterface {
    public func fileStructureCheck() -> Bool {
        for folderPath in folderPaths {
            let (isFileExists, isDirectory) = fileManager.fileOrDirectoryExists(atPath: mocksFolderPath + folderPath)

            guard isFileExists && isDirectory else { return false }
        }

        return true
    }

    public func domainFileStructureCheck(mockDomain: String) -> Bool {
        for folderPath in domainFolderPaths {
            let (isFileExists, isDirectory) = fileManager.fileOrDirectoryExists(atPath: mocksFolderPath + String(format: folderPath, arguments: [mockDomain]))

            guard isFileExists && isDirectory else { return false }
        }

        return true
    }

    public func createFileStructure() throws {
        for folderPath in folderPaths {
            let (isFileExists, isDirectory) = fileManager.fileOrDirectoryExists(atPath: mocksFolderPath + folderPath)

            guard !isFileExists || !isDirectory else { continue }

            let url = URL(filePath: mocksFolderPath + folderPath)
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }

    public func createDomainFileStructure(mockDomain: String) throws {
        guard !mockDomain.isEmpty else { return }
        
        for folderPath in domainFolderPaths {
            let (isFileExists, isDirectory) = fileManager.fileOrDirectoryExists(atPath: mocksFolderPath + String(format: folderPath, arguments: [mockDomain]))

            guard !isFileExists || !isDirectory else { continue }

            let url = URL(filePath: mocksFolderPath + String(format: folderPath, arguments: [mockDomain]))
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }

    public func repairFileStructure() throws {
        try createFileStructure()
    }

    public func repairDomainFileStructure(mockDomain: String) throws {
        try createDomainFileStructure(mockDomain: mockDomain)
    }
}
