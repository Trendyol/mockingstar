//
//  File.swift
//
//
//  Created by Yusuf Özgül on 1.09.2023.
//

import Foundation
@testable import CommonKit

public final class MockFileManager: FileManagerInterface {
    public init() { }
    
    public var invokedCreateDirectory = false
    public var invokedCreateDirectoryCount = 0
    public var invokedCreateDirectoryParameters: (url: URL, createIntermediates: Bool, attributes: [FileAttributeKey: Any]?, Void)?
    public var invokedCreateDirectoryParametersList: [(url: URL, createIntermediates: Bool, attributes: [FileAttributeKey: Any]?, Void)] = []
    public func createDirectory(
        at url: URL, withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws {
        invokedCreateDirectory = true
        invokedCreateDirectoryCount += 1
        invokedCreateDirectoryParameters = (url, createIntermediates, attributes, ())
        invokedCreateDirectoryParametersList.append((url, createIntermediates, attributes, ()))
    }

    public var invokedFileOrDirectoryExists = false
    public var invokedFileOrDirectoryExistsCount = 0
    public var invokedFileOrDirectoryExistsParameters: (path: String, Void)?
    public var invokedFileOrDirectoryExistsParametersList: [(path: String, Void)] = []
    public var stubbedFileOrDirectoryExistsResult: (isExist: Bool, isDirectory: Bool)!
    public func fileOrDirectoryExists(atPath path: String) -> (isExist: Bool, isDirectory: Bool) {
        invokedFileOrDirectoryExists = true
        invokedFileOrDirectoryExistsCount += 1
        invokedFileOrDirectoryExistsParameters = (path, ())
        invokedFileOrDirectoryExistsParametersList.append((path, ()))
        return stubbedFileOrDirectoryExistsResult
    }

    public var invokedFileExist = false
    public var invokedFileExistCount = 0
    public var invokedFileExistParameters: (path: String, Void)?
    public var invokedFileExistParametersList: [(path: String, Void)] = []
    public var stubbedFileExistResult: Bool!
    public func fileExist(atPath path: String) -> Bool {
        invokedFileExist = true
        invokedFileExistCount += 1
        invokedFileExistParameters = (path, ())
        invokedFileExistParametersList.append((path, ()))
        return stubbedFileExistResult
    }

    public var invokedWrite = false
    public var invokedWriteCount = 0
    public var invokedWriteParameters: (url: URL, fileName: String, model: Encodable, Void)?
    public var invokedWriteParametersList: [(url: URL, fileName: String, model: Encodable, Void)] = []
    public func write(to url: URL, fileName: String, model: Encodable) throws {
        invokedWrite = true
        invokedWriteCount += 1
        invokedWriteParameters = (url, fileName, model, ())
        invokedWriteParametersList.append((url, fileName, model, ()))
    }

    public var invokedReadJSONFile = false
    public var invokedReadJSONFileCount = 0
    public var invokedReadJSONFileParameters: (url: URL, Void)?
    public var invokedReadJSONFileParametersList: [(url: URL, Void)] = []
    public var stubbedReadJSONFileResult: Any!
    public var stubbedReadJSONFileError: Error? = nil
    public func readJSONFile<T>(at url: URL) throws -> T {
        invokedReadJSONFile = true
        invokedReadJSONFileCount += 1
        invokedReadJSONFileParameters = (url, ())
        invokedReadJSONFileParametersList.append((url, ()))

        if let stubbedReadJSONFileError {
            throw stubbedReadJSONFileError
        }

        return stubbedReadJSONFileResult as! T
    }

    public var invokedReadFile = false
    public var invokedReadFileCount = 0
    public var invokedReadFileParameters: (url: URL, Void)?
    public var invokedReadFileParametersList: [(url: URL, Void)] = []
    public var stubbedReadFileResult: String!
    public func readFile(at url: URL) throws -> String {
        invokedReadFile = true
        invokedReadFileCount += 1
        invokedReadFileParameters = (url, ())
        invokedReadFileParametersList.append((url, ()))
        return stubbedReadFileResult
    }

    public var invokedEnumerator = false
    public var invokedEnumeratorCount = 0
    public var invokedEnumeratorParameters: (
            url: URL, keys: [URLResourceKey]?, mask: FileManager.DirectoryEnumerationOptions,
            handler: ((URL, Error) -> Bool)?, Void)?
    public var invokedEnumeratorParametersList:
        [(
            url: URL, keys: [URLResourceKey]?, mask: FileManager.DirectoryEnumerationOptions,
            handler: ((URL, Error) -> Bool)?, Void
        )] = []
    public var stubbedEnumeratorResult: FileManager.DirectoryEnumerator?!
    public func enumerator(
        at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions,
        errorHandler handler: ((URL, Error) -> Bool)?
    ) -> FileManager.DirectoryEnumerator? {
        invokedEnumerator = true
        invokedEnumeratorCount += 1
        invokedEnumeratorParameters = (url, keys, mask, handler, ())
        invokedEnumeratorParametersList.append((url, keys, mask, handler, ()))
        return stubbedEnumeratorResult
    }

    public var invokedFolderContent = false
    public var invokedFolderContentCount = 0
    public var invokedFolderContentParameters: (url: URL, Void)?
    public var invokedFolderContentParametersList: [(url: URL, Void)] = []
    public var stubbedFolderContentResult: [URL]!
    public func folderContent(at url: URL) throws -> [URL] {
        invokedFolderContent = true
        invokedFolderContentCount += 1
        invokedFolderContentParameters = (url, ())
        invokedFolderContentParametersList.append((url, ()))
        return stubbedFolderContentResult
    }

    public var invokedMoveFile = false
    public var invokedMoveFileCount = 0
    public var invokedMoveFileParameters: (path: String, newPath: String, Void)?
    public var invokedMoveFileParametersList: [(path: String, newPath: String, Void)] = []
    public var stubbedMoveFileError: Error? = nil
    public func moveFile(from path: String, to newPath: String) throws {
        invokedMoveFile = true
        invokedMoveFileCount += 1
        invokedMoveFileParameters = (path, newPath, ())
        invokedMoveFileParametersList.append((path, newPath, ()))

        if let stubbedMoveFileError {
            throw stubbedMoveFileError
        }
    }

    public var invokedRemoveFile = false
    public var invokedRemoveFileCount = 0
    public var invokedRemoveFileParameters: (path: String, Void)?
    public var invokedRemoveFileParametersList: [(path: String, Void)] = []
    public var stubbedRemoveFileError: Error? = nil
    public func removeFile(at path: String) throws {
        invokedRemoveFile = true
        invokedRemoveFileCount += 1
        invokedRemoveFileParameters = (path, ())
        invokedRemoveFileParametersList.append((path, ()))

        if let stubbedRemoveFileError {
            throw stubbedRemoveFileError
        }
    }

    public var invokedUpdateFileContent = false
    public var invokedUpdateFileContentCount = 0
    public var invokedUpdateFileContentParameters: (path: String, content: Encodable, Void)?
    public var invokedUpdateFileContentParametersList: [(path: String, content: Encodable, Void)] = []
    public var stubbedUpdateFileContentError: Error? = nil
    public func updateFileContent(path: String, content: Encodable) throws {
        invokedUpdateFileContent = true
        invokedUpdateFileContentCount += 1
        invokedUpdateFileContentParameters = (path, content, ())
        invokedUpdateFileContentParametersList.append((path, content, ()))

        if let stubbedUpdateFileContentError {
            throw stubbedUpdateFileContentError
        }
    }
}
