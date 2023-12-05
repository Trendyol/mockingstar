//
//  FileSaverActor.swift
//
//
//  Created by Yusuf Özgül on 31.08.2023.
//

import CommonKit
import Foundation
import Combine

public protocol FileSaverActorInterface {
    func saveFile(mock: MockModel, mockDomain: String) async throws
}

public actor FileSaverActor: FileSaverActorInterface {
    private let logger = Logger(category: "FileSaverActor")
    private let fileManager: FileManagerInterface
    private var cancelableSet = Set<AnyCancellable>()
    public static let shared = FileSaverActor()
    @UserDefaultStorage("mockFolderFilePath") var mockFolderFilePath: String = "/MockServer"
    private var folderPath: String {
        if mockFolderFilePath.hasSuffix("/") { return mockFolderFilePath }
        return mockFolderFilePath + "/"
    }

    init(fileManager: FileManagerInterface = FileManager.default) {
        self.fileManager = fileManager
    }

    /// Saves a `MockModel` to a file within the specified mock domain's "Mocks" folder.
    ///
    /// This function performs the following steps:
    /// 1. Constructs the file path based on the provided `mock` and `mockDomain`.
    /// 2. Checks if a file already exists at the constructed path. If so, logs the information and returns without saving.
    /// 3. Writes the `MockModel` to the specified file path using the `fileManager`.
    ///
    /// - Parameters:
    ///   - mock: The `MockModel` to be saved.
    ///   - mockDomain: The mock domain under which the mock is saved.
    /// - Throws: If writing the file encounters an error, it is thrown.
    public func saveFile(mock: MockModel, mockDomain: String) throws {
        let filePath = folderPath + "Domains/" + mockDomain + "/Mocks/" + mock.folderPath

        guard !fileManager.fileExist(atPath: filePath) else {
            logger.info("Mock Already Saved at: \(filePath)")
            return
        }

        try fileManager.write(to: URL(filePath: filePath), fileName: mock.fileName, model: mock)
    }
}
