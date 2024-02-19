//
//  FileStructureHelperTests.swift
//
//
//  Created by Yusuf Özgül on 1.09.2023.
//

import XCTest
import CommonKit
import CommonKitTestSupport

final class FileStructureHelperTests: XCTestCase {
    private var fileManager: MockFileManager!
    private var fileStructureHelper: FileStructureHelper!
    private let defaults = UserDefaults()

    override func setUp() {
        fileManager = .init()

        @UserDefaultStorage("mockFolderFilePath", userDefaults: defaults) var mockFolderFilePath: String = ""
        mockFolderFilePath = "/MockServer/"

        fileStructureHelper = .init(fileManager: fileManager)
    }

    override func tearDown() {
        super.tearDown()
        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:))
    }

    func test_createFileStructure_CreateFolders() throws {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: false, isDirectory: false)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)
        XCTAssertFalse(fileManager.invokedCreateDirectory)

        try fileStructureHelper.createFileStructure()

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertTrue(fileManager.invokedCreateDirectory)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), ["/MockServer/Domains",
                                                                                            "/MockServer/Plugins"])
        XCTAssertEqual(fileManager.invokedCreateDirectoryParametersList.map(\.url.absoluteString), ["file:///MockServer/Domains",
                                                                                                    "file:///MockServer/Plugins"])
        XCTAssertEqual(fileManager.invokedCreateDirectoryParametersList.map(\.createIntermediates), [true, true])
    }

    func test_createFileStructure_FileExist_CreateFolders() throws {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: true, isDirectory: false)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)
        XCTAssertFalse(fileManager.invokedCreateDirectory)

        try fileStructureHelper.createFileStructure()

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertTrue(fileManager.invokedCreateDirectory)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), ["/MockServer/Domains",
                                                                                            "/MockServer/Plugins"])
        XCTAssertEqual(fileManager.invokedCreateDirectoryParametersList.map(\.url.absoluteString), ["file:///MockServer/Domains",
                                                                                                    "file:///MockServer/Plugins"])
        XCTAssertEqual(fileManager.invokedCreateDirectoryParametersList.map(\.createIntermediates), [true, true])
    }

    func test_createFileStructure_FolderExist_CreateFolders() throws {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: true, isDirectory: true)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)
        XCTAssertFalse(fileManager.invokedCreateDirectory)

        try fileStructureHelper.createFileStructure()

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertFalse(fileManager.invokedCreateDirectory)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), [
            "/MockServer/Domains",
            "/MockServer/Plugins",
        ])
    }

    func test_createDomainFileStructure_LocalDevelopment_CreateFolders() throws {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: false, isDirectory: false)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)
        XCTAssertFalse(fileManager.invokedCreateDirectory)

        try fileStructureHelper.createDomainFileStructure(mockDomain: "LocalDevelopment")

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertTrue(fileManager.invokedCreateDirectory)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), [
            "/MockServer/Domains/LocalDevelopment/Mocks",
            "/MockServer/Domains/LocalDevelopment/Configs",
            "/MockServer/Domains/LocalDevelopment/Plugins"
        ])
        XCTAssertEqual(fileManager.invokedCreateDirectoryParametersList.map(\.url.absoluteString), [
            "file:///MockServer/Domains/LocalDevelopment/Mocks",
            "file:///MockServer/Domains/LocalDevelopment/Configs",
            "file:///MockServer/Domains/LocalDevelopment/Plugins"
        ])
        XCTAssertEqual(fileManager.invokedCreateDirectoryParametersList.map(\.createIntermediates), [true, true, true])
    }
    func test_createDomainFileStructure_LocalDevelopment_FileExist_CreateFolders() throws {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: true, isDirectory: false)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)
        XCTAssertFalse(fileManager.invokedCreateDirectory)

        try fileStructureHelper.createDomainFileStructure(mockDomain: "LocalDevelopment")

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertTrue(fileManager.invokedCreateDirectory)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), [
            "/MockServer/Domains/LocalDevelopment/Mocks",
            "/MockServer/Domains/LocalDevelopment/Configs",
            "/MockServer/Domains/LocalDevelopment/Plugins"
        ])
        XCTAssertEqual(fileManager.invokedCreateDirectoryParametersList.map(\.url.absoluteString), [
            "file:///MockServer/Domains/LocalDevelopment/Mocks",
            "file:///MockServer/Domains/LocalDevelopment/Configs",
            "file:///MockServer/Domains/LocalDevelopment/Plugins"
        ])
        XCTAssertEqual(fileManager.invokedCreateDirectoryParametersList.map(\.createIntermediates), [true, true, true])
    }

    func test_createDomainFileStructure_LocalDevelopment_FolderExist_CreateFolders() throws {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: true, isDirectory: true)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)
        XCTAssertFalse(fileManager.invokedCreateDirectory)

        try fileStructureHelper.createDomainFileStructure(mockDomain: "LocalDevelopment")

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertFalse(fileManager.invokedCreateDirectory)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), [
            "/MockServer/Domains/LocalDevelopment/Mocks",
            "/MockServer/Domains/LocalDevelopment/Configs",
            "/MockServer/Domains/LocalDevelopment/Plugins"
        ])
    }

    func test_fileStructureCheck_ReturnTrue() {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: true, isDirectory: true)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)

        XCTAssertTrue(fileStructureHelper.fileStructureCheck())

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), ["/MockServer/Domains",
                                                                                            "/MockServer/Plugins"])
    }

    func test_fileStructureCheck_ReturnFalse() {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: true, isDirectory: false)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)

        XCTAssertFalse(fileStructureHelper.fileStructureCheck())

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), ["/MockServer/Domains"])
    }

    func test_fileStructureCheck_ReturnFalse_NotDirectory() {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: false, isDirectory: true)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)

        XCTAssertFalse(fileStructureHelper.fileStructureCheck())

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), ["/MockServer/Domains"])
    }

    func test_domainFileStructureCheck_ReturnTrue() {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: true, isDirectory: true)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)

        XCTAssertTrue(fileStructureHelper.domainFileStructureCheck(mockDomain: "LocalDevelopment"))

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), [
            "/MockServer/Domains/LocalDevelopment/Mocks",
            "/MockServer/Domains/LocalDevelopment/Configs",
            "/MockServer/Domains/LocalDevelopment/Plugins"
        ])
    }

    func test_domainFileStructureCheck_ReturnFalse() {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: true, isDirectory: false)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)

        XCTAssertFalse(fileStructureHelper.domainFileStructureCheck(mockDomain: "LocalDevelopment"))

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), ["/MockServer/Domains/LocalDevelopment/Mocks"])
    }

    func test_domainFileStructureCheck_ReturnFalse_NotDirectory() {
        fileManager.stubbedFileOrDirectoryExistsResult = (isExist: false, isDirectory: true)

        XCTAssertFalse(fileManager.invokedFileOrDirectoryExists)

        XCTAssertFalse(fileStructureHelper.domainFileStructureCheck(mockDomain: "LocalDevelopment"))

        XCTAssertTrue(fileManager.invokedFileOrDirectoryExists)
        XCTAssertEqual(fileManager.invokedFileOrDirectoryExistsParametersList.map(\.path), ["/MockServer/Domains/LocalDevelopment/Mocks"])
    }
}
