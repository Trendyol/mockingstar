//
//  FileSaverActorTests.swift
//  
//
//  Created by Yusuf Özgül on 1.09.2023.
//

import CommonKit
import CommonKitTestSupport
import XCTest
@testable import MockingStarCore

final class FileSaverActorTests: XCTestCase {
    private var actor: FileSaverActor!
    private var fileManager: MockFileManager!
    private let defaults = UserDefaults()

    override func setUp() {
        super.setUp()

        @UserDefaultStorage("workspaces", userDefaults: defaults) var workspaces: [Workspace] = []
        workspaces = [Workspace(name: "Workspace", path: "/MockServer/", bookmark: Data())]

        fileManager = .init()
        actor = .init(fileManager: fileManager)
    }

    override func tearDown() {
        super.tearDown()
        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:))
    }

    @MainActor
    func test_saveFile_SaveFilePath() async throws {
        fileManager.stubbedFileExistResult = false

        XCTAssertFalse(fileManager.invokedFileExist)
        XCTAssertFalse(fileManager.invokedWrite)

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))

        try await actor.saveFile(mock: .init(metaData: .init(url: url,
                                                             method: "GET",
                                                             appendTime: .init(),
                                                             updateTime: .init(),
                                                             httpStatus: 200,
                                                             responseTime: 0.15,
                                                             scenario: "",
                                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                                             requestHeader: "",
                                             responseHeader: "",
                                             requestBody: .init("hello 123"),
                                             responseBody: .init("hello 321")),
                                 mockDomain: "LocalDevelopment")


        XCTAssertTrue(fileManager.invokedFileExist)
        XCTAssertTrue(fileManager.invokedWrite)
        XCTAssertEqual(fileManager.invokedWriteParametersList.map(\.url.absoluteString), ["file:///MockServer/Domains/LocalDevelopment/Mocks/aboutus/GET"])
        XCTAssertEqual(fileManager.invokedWriteParametersList.map(\.fileName), ["aboutus_9271C0BE-9326-443F-97B8-1ECA29571FC3.json"])
    }

    @MainActor
    func test_saveFile_longFileName_SaveFilePath() async throws {
        fileManager.stubbedFileExistResult = false

        XCTAssertFalse(fileManager.invokedFileExist)
        XCTAssertFalse(fileManager.invokedWrite)

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus"))

        try await actor.saveFile(mock: .init(metaData: .init(url: url,
                                                             method: "GET",
                                                             appendTime: .init(),
                                                             updateTime: .init(),
                                                             httpStatus: 200,
                                                             responseTime: 0.15,
                                                             scenario: "",
                                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                                             requestHeader: "",
                                             responseHeader: "",
                                             requestBody: .init("hello 123"),
                                             responseBody: .init("hello 321")),
                                 mockDomain: "LocalDevelopment")


        XCTAssertTrue(fileManager.invokedFileExist)
        XCTAssertTrue(fileManager.invokedWrite)
        XCTAssertEqual(fileManager.invokedWriteParametersList.map(\.url.absoluteString), ["file:///MockServer/Domains/LocalDevelopment/Mocks/aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus-aboutus/GET"])
        XCTAssertEqual(fileManager.invokedWriteParametersList.map(\.fileName), ["9271C0BE-9326-443F-97B8-1ECA29571FC3.json"])
    }


    @MainActor
    func test_saveFile_FileExist_SaveFilePath() async throws {
        fileManager.stubbedFileExistResult = true

        XCTAssertFalse(fileManager.invokedFileExist)
        XCTAssertFalse(fileManager.invokedWrite)

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))

        try await actor.saveFile(mock: .init(metaData: .init(url: url,
                                                             method: "GET",
                                                             appendTime: .init(),
                                                             updateTime: .init(),
                                                             httpStatus: 200,
                                                             responseTime: 0.15,
                                                             scenario: "",
                                                             id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                                             requestHeader: "",
                                             responseHeader: "",
                                             requestBody: .init("hello 123"),
                                             responseBody: .init("hello 321")),
                                 mockDomain: "LocalDevelopment")


        XCTAssertTrue(fileManager.invokedFileExist)
        XCTAssertFalse(fileManager.invokedWrite)
    }
}
