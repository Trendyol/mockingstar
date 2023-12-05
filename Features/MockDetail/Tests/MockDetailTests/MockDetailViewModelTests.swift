//
//  MockDetailViewModelTests.swift
//  
//
//  Created by Yusuf Özgül on 4.12.2023.
//

@testable import MockDetail
import XCTest
import CommonKit
import CommonKitTestSupport
import MockingStarCoreTestSupport
import CommonViewsKitTestSupport

final class MockDetailViewModelTests: XCTestCase {
    private var viewModel: MockDetailViewModel!
    private var fileManager: MockFileManager!
    private var fileSaver: MockFileSaverActor!
    private var notificationManager: MockNotificationManager!
    private var pasteBoard: MockNSPasteboard!
    private var nsWorkspace: MockNSWorkspace!
    private let defaults = UserDefaults.standard

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = .init()
        fileSaver = .init()
        notificationManager = .init()
        pasteBoard = .init()
        nsWorkspace = .init()

        let url = try XCTUnwrap(URL(string: "https://www.trendyol.com/aboutus"))
        let model = MockModel(metaData: .init(url: url,
                                              method: "GET",
                                              appendTime: .init(),
                                              updateTime: .init(),
                                              httpStatus: 200,
                                              responseTime: 0.15,
                                              scenario: "EmptyCase",
                                              id: "9271C0BE-9326-443F-97B8-1ECA29571FC3"),
                              requestHeader: "",
                              responseHeader: "",
                              requestBody: .init(""),
                              responseBody: .init(""))
        model.fileURL = URL(filePath: "/foo/bar/file/path/mock.json")

        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:))

        viewModel = .init(mockModel: model,
                          mockDomain: "TEST",
                          fileManager: fileManager,
                          fileSaver: fileSaver,
                          notificationManager: notificationManager,
                          pasteBoard: pasteBoard,
                          nsWorkspace: nsWorkspace)
    }

    override func tearDown() {
        super.tearDown()
        defaults.dictionaryRepresentation().keys.forEach(defaults.removeObject(forKey:))
    }

    func test_saveChanges_InvokesNecessaryMethods() {
        viewModel.mockModel.metaData.responseTime = 0.1

        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)
        XCTAssertFalse(fileManager.invokedUpdateFileContent)
        XCTAssertFalse(fileManager.invokedMoveFile)
        XCTAssertFalse(notificationManager.invokedShow)

        viewModel.saveChanges()

        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)
        XCTAssertTrue(fileManager.invokedUpdateFileContent)
        XCTAssertFalse(fileManager.invokedMoveFile)
        XCTAssertTrue(notificationManager.invokedShow)
        XCTAssertEqual(fileManager.invokedUpdateFileContentParametersList.map(\.path), ["/foo/bar/file/path/mock.json"])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.title), ["All changes saved"])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.color), [.green])
    }

    func test_saveChanges_MoveRequired_InvokesNecessaryMethods() {
        viewModel.mockModel.metaData.scenario = "Test"

        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)
        XCTAssertFalse(fileManager.invokedUpdateFileContent)
        XCTAssertFalse(fileManager.invokedMoveFile)
        XCTAssertFalse(notificationManager.invokedShow)

        viewModel.saveChanges()

        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)
        XCTAssertTrue(fileManager.invokedUpdateFileContent)
        XCTAssertTrue(fileManager.invokedMoveFile)
        XCTAssertTrue(notificationManager.invokedShow)
        XCTAssertEqual(fileManager.invokedUpdateFileContentParametersList.map(\.path), ["/foo/bar/file/path/mock.json"])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.title), ["All changes saved"])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.color), [.green])
    }

    func test_saveChanges_NotChange_InvokesNecessaryMethods() {
        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)
        XCTAssertFalse(fileManager.invokedUpdateFileContent)
        XCTAssertFalse(fileManager.invokedMoveFile)
        XCTAssertFalse(notificationManager.invokedShow)

        viewModel.saveChanges()

        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)
        XCTAssertFalse(fileManager.invokedUpdateFileContent)
        XCTAssertFalse(fileManager.invokedMoveFile)
        XCTAssertFalse(notificationManager.invokedShow)
    }

    func test_saveChanges_Failed_InvokesNecessaryMethods() {
        viewModel.mockModel.metaData.responseTime = 0.1
        fileManager.stubbedUpdateFileContentError = NSError(domain: "Failed", code: -1)

        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)
        XCTAssertFalse(fileManager.invokedUpdateFileContent)
        XCTAssertFalse(fileManager.invokedMoveFile)
        XCTAssertFalse(notificationManager.invokedShow)

        viewModel.saveChanges()

        XCTAssertEqual(viewModel.saveErrorMessage, """
        Mock couldn't saved
        Error Domain=Failed Code=-1 "(null)"
        """)
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, true)
        XCTAssertTrue(fileManager.invokedUpdateFileContent)
        XCTAssertFalse(fileManager.invokedMoveFile)
        XCTAssertFalse(notificationManager.invokedShow)
        XCTAssertEqual(fileManager.invokedUpdateFileContentParametersList.map(\.path), ["/foo/bar/file/path/mock.json"])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.title), [])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.color), [])
    }

    func test_removeMock_InvokesNecessaryMethods() {
        XCTAssertFalse(fileManager.invokedRemoveFile)
        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)

        viewModel.removeMock()

        XCTAssertTrue(fileManager.invokedRemoveFile)
        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)
        XCTAssertEqual(fileManager.invokedRemoveFileParametersList.map(\.path), ["/foo/bar/file/path/mock.json"])
    }

    func test_removeMock_Failed_InvokesNecessaryMethods() {
        fileManager.stubbedRemoveFileError = NSError(domain: "Failed", code: -1)

        XCTAssertFalse(fileManager.invokedRemoveFile)
        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)

        viewModel.removeMock()

        XCTAssertTrue(fileManager.invokedRemoveFile)
        XCTAssertEqual(viewModel.saveErrorMessage, """
        Mock couldn't delete
        Error Domain=Failed Code=-1 "(null)"
        """)
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, true)
        XCTAssertEqual(fileManager.invokedRemoveFileParametersList.map(\.path), ["/foo/bar/file/path/mock.json"])
    }

    func test_openInFinder_InvokesWorkSpace() {
        nsWorkspace.stubbedSelectFileResult = true

        XCTAssertFalse(nsWorkspace.invokedSelectFile)

        viewModel.openInFinder()

        XCTAssertTrue(nsWorkspace.invokedSelectFile)
        XCTAssertEqual(nsWorkspace.invokedSelectFileParametersList.map(\.fullPath), ["/foo/bar/file/path/mock.json"])
        XCTAssertEqual(nsWorkspace.invokedSelectFileParametersList.map(\.rootFullPath), ["/foo/bar/file/path"])
    }

    func test_checkFilePath_SetVariable() {
        XCTAssertFalse(viewModel.shouldShowFilePathErrorAlert)

        viewModel.checkFilePath()

        XCTAssertTrue(viewModel.shouldShowFilePathErrorAlert)
    }

    func test_fixFilePath_InvokesNecessaryMethods() {
        XCTAssertFalse(fileManager.invokedMoveFile)
        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)

        viewModel.fixFilePath()

        XCTAssertTrue(fileManager.invokedMoveFile)
        XCTAssertEqual(fileManager.invokedMoveFileParametersList.map(\.newPath), ["/MockServerDomains/TEST/Mocks/aboutus/GET/aboutus_EmptyCase_9271C0BE-9326-443F-97B8-1ECA29571FC3.json"])
        XCTAssertEqual(fileManager.invokedMoveFileParametersList.map(\.path), ["/foo/bar/file/path/mock.json"])
        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)
    }

    func test_fixFilePath_Failed_InvokesNecessaryMethods() {
        fileManager.stubbedMoveFileError = NSError(domain: "Failed", code: -1)

        XCTAssertFalse(fileManager.invokedMoveFile)
        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)

        viewModel.fixFilePath()

        XCTAssertTrue(fileManager.invokedMoveFile)
        XCTAssertEqual(fileManager.invokedMoveFileParametersList.map(\.newPath), ["/MockServerDomains/TEST/Mocks/aboutus/GET/aboutus_EmptyCase_9271C0BE-9326-443F-97B8-1ECA29571FC3.json"])
        XCTAssertEqual(fileManager.invokedMoveFileParametersList.map(\.path), ["/foo/bar/file/path/mock.json"])
        XCTAssertEqual(viewModel.saveErrorMessage, "The operation couldn’t be completed. (Failed error -1.)")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, true)
    }

    func test_discardChanges_ResetMockModel() {
        viewModel.mockModel.metaData.scenario = "TEST"

        viewModel.discardChanges()

        XCTAssertEqual(viewModel.mockModel.metaData.scenario, "EmptyCase")
    }

    func test_shareButtonTapped_Curl_CopyExport() {
        pasteBoard.stubbedClearContentsResult = 0
        pasteBoard.stubbedSetStringResult = true

        XCTAssertFalse(pasteBoard.invokedClearContents)
        XCTAssertFalse(pasteBoard.invokedSetString)
        XCTAssertFalse(notificationManager.invokedShow)

        viewModel.shareButtonTapped(shareStyle: .curl)

        XCTAssertTrue(pasteBoard.invokedClearContents)
        XCTAssertTrue(pasteBoard.invokedSetString)
        XCTAssertTrue(notificationManager.invokedShow)
        XCTAssertEqual(pasteBoard.invokedSetStringParametersList.map(\.string), ["curl --request GET \\\n--url \'https://www.trendyol.com/aboutus\' \\\n"])
        XCTAssertEqual(pasteBoard.invokedSetStringParametersList.map(\.dataType), [.string])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.title), ["Request copied to clipboard"])
        XCTAssertEqual(notificationManager.invokedShowParametersList.map(\.color), [.green])

    }

    func test_checkUnsavedChanges_CheckDiff() {
        XCTAssertFalse(viewModel.shouldShowUnsavedIndicator)

        viewModel.mockModel.metaData.scenario = "TEST"
        viewModel.checkUnsavedChanges()

        XCTAssertTrue(viewModel.shouldShowUnsavedIndicator)
    }

    func test_checkUnsavedChanges_NoDiff_CheckDiff() {
        XCTAssertFalse(viewModel.shouldShowUnsavedIndicator)

        viewModel.checkUnsavedChanges()

        XCTAssertFalse(viewModel.shouldShowUnsavedIndicator)
    }

    func test_duplicateMock_InvokesNecessaryMethods() async {
        XCTAssertFalse(fileSaver.invokedSaveFile)
        XCTAssertFalse(notificationManager.invokedShow)
        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)

        await viewModel.duplicateMock()

        XCTAssertTrue(fileSaver.invokedSaveFile)
        XCTAssertTrue(notificationManager.invokedShow)
        XCTAssertNotEqual(viewModel.mockModel.id, fileSaver.invokedSaveFileParameters?.mock.id)
        XCTAssertEqual(fileSaver.invokedSaveFileParametersList.map(\.mockDomain), ["TEST"])
        XCTAssertEqual(fileSaver.invokedSaveFileParametersList.map(\.mock.metaData.url.absoluteString), ["https://www.trendyol.com/aboutus"])
        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)
    }

    func test_duplicateMock_Failed_InvokesNecessaryMethods() async {
        fileSaver.stubbedSaveFileError = NSError(domain: "Failed", code: -1)

        XCTAssertFalse(fileSaver.invokedSaveFile)
        XCTAssertFalse(notificationManager.invokedShow)
        XCTAssertEqual(viewModel.saveErrorMessage, "")
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, false)

        await viewModel.duplicateMock()

        XCTAssertTrue(fileSaver.invokedSaveFile)
        XCTAssertFalse(notificationManager.invokedShow)
        XCTAssertNotEqual(viewModel.mockModel.id, fileSaver.invokedSaveFileParameters?.mock.id)
        XCTAssertEqual(fileSaver.invokedSaveFileParametersList.map(\.mockDomain), ["TEST"])
        XCTAssertEqual(fileSaver.invokedSaveFileParametersList.map(\.mock.metaData.url.absoluteString), ["https://www.trendyol.com/aboutus"])
        XCTAssertEqual(viewModel.saveErrorMessage, """
                       Mock couldn't duplicated
                       Error Domain=Failed Code=-1 "(null)"
                       """)
        XCTAssertEqual(viewModel.shouldShowSaveErrorAlert, true)
    }
}
