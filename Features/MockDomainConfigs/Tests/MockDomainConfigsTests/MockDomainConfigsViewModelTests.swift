//
//  MockDomainConfigsViewModelTests.swift
//  
//
//  Created by Yusuf Özgül on 6.12.2023.
//

@testable import MockDomainConfigs
import XCTest
import CommonKitTestSupport
import CommonViewsKitTestSupport
import CommonKit

final class MockDomainConfigsViewModelTests: XCTestCase {
    private var viewModel: MockDomainConfigsViewModel!
    private var fileManager: MockFileManager!
    private var fileUrlBuilder: MockFileUrlBuilder!
    private var fileStructureMonitor: MockFileStructureMonitor!
    private var notificationManager: MockNotificationManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = .init()
        fileUrlBuilder = .init()
        fileStructureMonitor = .init()
        notificationManager = .init()

        viewModel = .init(fileManager: fileManager,
                          fileUrlBuilder: fileUrlBuilder,
                          fileStructureMonitor: fileStructureMonitor,
                          notificationManager: notificationManager)
    }

    func test_mockDomainUpdated_InvokesNecessaryMethods() {
        fileUrlBuilder.stubbedConfigUrlResult = URL(string: "configs/file/path")
        fileUrlBuilder.stubbedConfigsFolderUrlResult = URL(string: "configs/file/")
        fileManager.stubbedReadJSONFileResult = ConfigModel()

        XCTAssertFalse(fileUrlBuilder.invokedConfigUrl)
        XCTAssertFalse(fileManager.invokedReadJSONFile)
        XCTAssertFalse(fileManager.invokedWrite)

        viewModel.mockDomainUpdated(mockDomain: "TestDomain")

        XCTAssertFalse(fileManager.invokedWrite)
        XCTAssertTrue(fileUrlBuilder.invokedConfigUrl)
        XCTAssertTrue(fileManager.invokedReadJSONFile)
        XCTAssertEqual(fileUrlBuilder.invokedConfigsFolderUrlParametersList.map(\.mockDomain), ["TestDomain"])
        XCTAssertEqual(fileManager.invokedReadJSONFileParametersList.map(\.url), [.init(string: "configs/file/path")!])
    }

    func test_mockDomainUpdated_fileNotFound_InvokesNecessaryMethods() {
        fileUrlBuilder.stubbedConfigUrlResult = URL(string: "configs/file/path")
        fileUrlBuilder.stubbedConfigsFolderUrlResult = URL(string: "configs/file/")
        fileManager.stubbedReadJSONFileResult = ConfigModel()
        fileManager.stubbedReadJSONFileError = FileManagerError.fileNotFound

        XCTAssertFalse(fileUrlBuilder.invokedConfigUrl)
        XCTAssertFalse(fileManager.invokedReadJSONFile)
        XCTAssertFalse(fileManager.invokedWrite)

        viewModel.mockDomainUpdated(mockDomain: "TestDomain")

        XCTAssertTrue(fileUrlBuilder.invokedConfigUrl)
        XCTAssertTrue(fileManager.invokedReadJSONFile)
        XCTAssertTrue(fileManager.invokedWrite)
        XCTAssertEqual(fileManager.invokedWriteParametersList.map(\.fileName), ["path"])
        XCTAssertEqual(fileManager.invokedWriteParametersList.map(\.url), [.init(string: "configs/file/")!])
        XCTAssertEqual(fileUrlBuilder.invokedConfigsFolderUrlParametersList.map(\.mockDomain), ["TestDomain", "TestDomain"])
    }

    func test_saveChanges_InvokesNecessaryMethods() {
        fileUrlBuilder.stubbedConfigUrlResult = URL(string: "configs/file/path")
        viewModel.appFilterConfigs.domains = [.init(domain: "trendyol.com")]

        XCTAssertFalse(fileUrlBuilder.invokedConfigUrl)
        XCTAssertFalse(fileManager.invokedUpdateFileContent)
        XCTAssertFalse(notificationManager.invokedShow)

        viewModel.saveChanges()

        XCTAssertTrue(fileUrlBuilder.invokedConfigUrl)
        XCTAssertTrue(fileManager.invokedUpdateFileContent)
        XCTAssertTrue(notificationManager.invokedShow)
        XCTAssertEqual(fileManager.invokedUpdateFileContentParametersList.map(\.path), ["configs/file/path"])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.title), ["All changes saved"])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.color), [.green])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.dismissTime), [6.0])
    }

}
