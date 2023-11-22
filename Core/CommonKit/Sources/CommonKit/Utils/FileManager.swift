//
//  File.swift
//
//
//  Created by Yusuf Özgül on 1.09.2023.
//

import Foundation

public enum FileManagerError: LocalizedError {
    case modelEncodingError(Error)
    case writeFileError(Error)
    case fileNotFound
    case wrongFileModelType(Error)
    case fileAlreadyExist
    case moveFileError(Error)
    case deleteError(Error)

    public var errorDescription: String? {
        return switch self {
        case .modelEncodingError(let error): "Model JSON Encoding error: \(error.localizedDescription)"
        case .writeFileError(let error): "File Write error: \(error.localizedDescription)"
        case .fileNotFound: "File not found given path"
        case .wrongFileModelType(let error): "File loaded but given model type can not decoded error: \(error.localizedDescription)"
        case .fileAlreadyExist: "A file already exists in the location you want to move"
        case .moveFileError(let error): "File moving failed, error: \(error.localizedDescription)"
        case .deleteError(let error): "File couldn't delete, error: \(error.localizedDescription)"
        }
    }
}

public protocol FileManagerInterface {
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws

    /// Checks whether a file or directory exists at the specified path.
    ///
    /// - Parameter path: The path to the file or directory.
    /// - Returns: A tuple containing information about existence and whether it's a directory.
    ///   - isExist: `true` if the file or directory exists, otherwise `false`.
    ///   - isDirectory: `true` if the path points to a directory, otherwise `false`.
    func fileOrDirectoryExists(atPath path: String) -> (isExist: Bool, isDirectory: Bool)

    /// Checks whether a file exists at the specified path.
    ///
    /// - Parameter path: The path to the file.
    /// - Returns: `true` if a file exists at the specified path, otherwise `false`.
    func fileExist(atPath path: String) -> Bool

    /// Writes the encoded representation of a model to a file at the specified URL with the given file name.
    ///
    /// - Parameters:
    ///   - url: The URL of the directory where the file will be created.
    ///   - fileName: The name of the file to be created.
    ///   - model: The data model to be encoded and written to the file.
    /// - Throws:
    ///   - If encoding the model encounters an error of type `EncodingError`, a `FileManagerError.modelEncodingError` is thrown.
    ///   - If creating the directory or writing the file encounters any other error, a `FileManagerError.writeFileError` is thrown.
    func write(to url: URL, fileName: String, model: Encodable) throws

    /// Reads and decodes a JSON file at the specified URL into a model of the specified type.
    ///
    /// - Parameters:
    ///   - url: The URL of the JSON file to be read and decoded.
    /// - Returns: A model of the specified type, decoded from the contents of the JSON file.
    /// - Throws:
    ///   - If reading or decoding the file encounters an error of type `DecodingError`, a `FileManagerError.wrongFileModelType` is thrown.
    ///   - If the file is not found at the specified URL, a `FileManagerError.fileNotFound` is thrown.
    func readJSONFile<T: Decodable>(at url: URL) throws -> T

    /// Reads the contents of a file at the specified URL and returns it as a string.
    ///
    /// - Parameters:
    ///   - url: The URL of the file to be read.
    /// - Returns: The contents of the file as a string.
    /// - Throws: If the file is not found at the specified URL, a `FileManagerError.fileNotFound` is thrown.
    func readFile(at url: URL) throws -> String
    func enumerator(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions, errorHandler handler: ((URL, Error) -> Bool)?) -> FileManager.DirectoryEnumerator?

    /// Retrieves the contents (files and directories) of a folder at the specified URL.
    ///
    /// - Parameters:
    ///   - url: The URL of the folder to retrieve the contents from.
    /// - Returns: An array of URLs representing the contents of the folder.
    /// - Throws: If the folder does not exist at the specified URL, an empty array is returned.
    ///           Other errors during the content retrieval process are propagated.
    func folderContent(at url: URL) throws -> [URL]

    /// Moves a file from one path to another.
    ///
    /// - Parameters:
    ///   - path: The path of the file to be moved.
    ///   - newPath: The destination path where the file will be moved to.
    /// - Throws:
    ///   - If the destination path already contains a file with the same name, a `FileManagerError.fileAlreadyExist` is thrown.
    ///   - If creating the necessary directory structure or moving the file encounters any other error, a `FileManagerError.moveFileError` is thrown.
    func moveFile(from path: String, to newPath: String) throws

    /// Removes the specified file.
    ///
    /// - Parameters:
    ///   - path: The path to the file to be removed.
    /// - Throws: If an error occurs during the file removal process, a `FileManagerError.deleteError` is thrown.
    func removeFile(at path: String) throws

    /// Updates the content of the file at the specified path with the encoded representation of the provided data.
    ///
    /// - Parameters:
    ///   - path: The path to the file to be updated.
    ///   - content: The data to be encoded and written to the file.
    /// - Throws:
    ///   - If encoding the content encounters an error of type `EncodingError`, a `FileManagerError.modelEncodingError` is thrown.
    ///   - If writing the encoded data to the file encounters any other error, a `FileManagerError.writeFileError` is thrown.
    func updateFileContent(path: String, content: Encodable) throws
}

extension FileManager: FileManagerInterface {
    public func fileOrDirectoryExists(atPath path: String) -> (isExist: Bool, isDirectory: Bool) {
        var isDirectory: ObjCBool = false
        let isFileExists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

        return (isFileExists, isDirectory.boolValue)
    }

    public func fileExist(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let isFileExists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return isFileExists && !isDirectory.boolValue
    }

    public func write(to url: URL, fileName: String, model: Encodable) throws {
        do {
            let data = try JSONEncoder.shared.encode(model)
            try createDirectory(at: url, withIntermediateDirectories: true)
            createFile(atPath: url.path() + "/" + fileName, contents: data)
        } catch where error is EncodingError {
            throw FileManagerError.modelEncodingError(error)
        } catch {
            throw FileManagerError.writeFileError(error)
        }
    }

    public func readJSONFile<T: Decodable>(at url: URL) throws -> T {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder.shared.decode(T.self, from: data)
        } catch where error is DecodingError {
            throw FileManagerError.wrongFileModelType(error)
        } catch {
            throw FileManagerError.fileNotFound
        }
    }

    public func readFile(at url: URL) throws -> String {
        do {
            return try String(contentsOf: url)
        } catch {
            throw FileManagerError.fileNotFound
        }
    }

    private func contentsOfDirectoryForGeneric(at url: URL, remainingPathItems: [String]) throws -> [URL] {
        guard fileOrDirectoryExists(atPath: url.path(percentEncoded: false)).isExist else { return [] }

        let contents = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil,  options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])

        if remainingPathItems.isEmpty {
            return contents
        }

        return try contents.flatMap {
            try contentsOfDirectoryForGeneric(at: $0.appending(path: remainingPathItems.first.orEmpty), remainingPathItems: Array(remainingPathItems.dropFirst()))
        }
    }

    public func folderContent(at url: URL) throws -> [URL] {
        guard url.path().contains("*") else {
            guard fileOrDirectoryExists(atPath: url.path(percentEncoded: false)).isExist else { return [] }
            return try contentsOfDirectory(at: url, includingPropertiesForKeys: nil,  options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        }

        guard let headUrl = URL(string: url.path().components(separatedBy: "*").first.orEmpty) else { return [] }
        let components = url.path().components(separatedBy: "*")
        return try contentsOfDirectoryForGeneric(at: headUrl, remainingPathItems: Array(components.dropFirst()))
    }

    public func moveFile(from path: String, to newPath: String) throws {
        let folderPath = newPath.components(separatedBy: "/").dropLast().joined(separator: "/")
        if fileExists(atPath: newPath) {
            throw FileManagerError.fileAlreadyExist
        }

        do {
            try createDirectory(atPath: folderPath, withIntermediateDirectories: true)
            try moveItem(atPath: path, toPath: newPath)
        } catch {
            throw FileManagerError.moveFileError(error)
        }
    }

    public func removeFile(at path: String) throws {
        do {
            try removeItem(atPath: path)
        } catch {
            throw FileManagerError.deleteError(error)
        }
    }

    public func updateFileContent(path: String, content: Encodable) throws {
        do {
            let data = try JSONEncoder.shared.encode(content)
            try data.write(to: URL(filePath: path), options: .atomic)
        } catch where error is EncodingError {
            throw FileManagerError.modelEncodingError(error)
        } catch {
            throw FileManagerError.writeFileError(error)
        }
    }
}
